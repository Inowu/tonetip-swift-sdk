//
//  TonetipListener.swift
//

import AVFoundation
import Accelerate

public class TonetipListenerBase: NSObject {
    public var onDecodedTone: ((String, Int) -> Void)?

    private let frequencies: [Int]
    private var decoders: [(dec: DecoderMFSK, freq: Int)] = []

    private var audioSession: AVAudioSession!
    private var audioEngine: AVAudioEngine!
    private var converter: AVAudioConverter?
    private var desiredFormat: AVAudioFormat!

    // Tap
    private var tapInstalled = false
    private let tapBufferSize: AVAudioFrameCount = 4096

    public var forceBuiltInMic: Bool = false

    public var debugEnabled: Bool = false
    private var dbgFrames = 0
    private var dbgLast = CFAbsoluteTimeGetCurrent()

    // ---- Inits ----
    public convenience init(frequency: Int) { self.init(frequencies: [frequency]) }

    public init(frequencies: [Int]) {
        self.frequencies = frequencies
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public

    public func start(completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.configureSession()
                try self.configureEngine()

                self.decoders = self.frequencies.map { (DecoderMFSK(speed: 2, freq: Float($0)), $0) }

                try self.audioSession.setActive(true, options: [])
                try self.audioEngine.start()
                DispatchQueue.main.async { completion(nil) }
                if self.debugEnabled { print("🎙️ Listening at \(self.frequencies) Hz") }
            } catch {
                if self.debugEnabled { print("❌ Failed to start listener:", error) }
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    public func stop() {
        removeTapIfNeeded()
        audioEngine?.stop()
        try? audioSession?.setActive(false, options: [])
        NotificationCenter.default.removeObserver(self)
        if debugEnabled { print("🛑 Stopped \(frequencies)Hz") }
    }

    // MARK: - Session

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .record,
            options: [.mixWithOthers]
        )
        try session.setMode(.measurement)
        
        if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? session.setPreferredInput(builtIn)
        }

        desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!

        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(1024.0 / 48_000.0)

        if forceBuiltInMic,
           let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? session.setPreferredInput(builtIn)
        }

        audioSession = session
        try session.setActive(true, options: [])

        // Notifs
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )

        if debugEnabled { dbgPrintRouteOnce() }
    }

    // MARK: - Engine

    private func configureEngine() throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        installTapIfNeeded(on: input, format: inputFormat)
        audioEngine = engine
        converter = nil
    }

    private func installTapIfNeeded(on node: AVAudioNode, format: AVAudioFormat) {
        guard !tapInstalled else { return }
        node.installTap(onBus: 0, bufferSize: tapBufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        tapInstalled = true
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        audioEngine?.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    // MARK: - Processing

    private func rebuildConverterIfNeeded(inputFormat: AVAudioFormat) {
        if converter == nil ||
           converter?.inputFormat.sampleRate != inputFormat.sampleRate ||
           converter?.inputFormat.channelCount != inputFormat.channelCount ||
           converter?.inputFormat.commonFormat != inputFormat.commonFormat {
            converter = AVAudioConverter(from: inputFormat, to: desiredFormat)
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        rebuildConverterIfNeeded(inputFormat: buffer.format)
        guard let converter = converter else { return }

        let inFrames = Int(buffer.frameLength)
        guard inFrames > 0 else { return }

        let ratio = desiredFormat.sampleRate / buffer.format.sampleRate
        let outCap = AVAudioFrameCount(Double(inFrames) * ratio + 64.0)
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: desiredFormat, frameCapacity: outCap) else { return }

        do {
            try converter.convert(to: outBuf, from: buffer)
        } catch {
            self.converter = nil
            if debugEnabled { print("⚠️ AVAudioConverter reset due to error:", error) }
            return
        }

        let frames = Int(outBuf.frameLength)
        guard frames > 0, let ch0 = outBuf.floatChannelData?.pointee else { return }

        if debugEnabled {
            var acc: Float = 0
            vDSP_svesq(ch0, 1, &acc, vDSP_Length(frames))
            let rms = sqrt(max(acc, 0) / Float(max(frames, 1)))
            dbgFrames += frames
            let now = CFAbsoluteTimeGetCurrent()
            if now - dbgLast > 1.0 {
                dbgLast = now
                print(String(format: "📻 Tap: ~%d fr/s, rms=%.5f (inSR=%.0f → outSR=%.0f)",
                             dbgFrames, rms, buffer.format.sampleRate, desiredFormat.sampleRate))
                dbgFrames = 0
            }
        }

        var int16 = [Int16](repeating: 0, count: frames)
        for i in 0..<frames {
            let x = max(-1.0, min(1.0, ch0[i]))
            int16[i] = Int16(x * 32767.0)
        }

        for (dec, f) in decoders {
            if let uarc = dec.processSamples(int16) {
                DispatchQueue.main.async { [weak self] in
                    self?.onDecodedTone?(uarc, f)
                }
            }
        }
    }

    // MARK: - Route / interruptions

    @objc private func handleRouteChange(_ n: Notification) {
        converter = nil

        if forceBuiltInMic,
           let builtIn = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? audioSession.setPreferredInput(builtIn)
        }

        if debugEnabled { dbgPrintRouteOnce() }
    }

    @objc private func handleInterruption(_ n: Notification) {
        guard let info = n.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }

        switch type {
        case .began:
            if debugEnabled { print("⏸️ Interruption began") }
        case .ended:
            if debugEnabled { print("▶️ Interruption ended — restarting engine") }
            try? audioSession.setActive(true)
            if !(audioEngine?.isRunning ?? false) {
                try? audioEngine.start()
            }
        @unknown default:
            break
        }
    }

    private func dbgPrintRouteOnce() {
        guard debugEnabled else { return }
        let r = audioSession.currentRoute
        let ins = r.inputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        let outs = r.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        print("🎛️ Route in=[\(ins)] out=[\(outs)] sr=\(audioSession.sampleRate)")
    }
}
