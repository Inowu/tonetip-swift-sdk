//
//  TonetipListenerBase.swift
//

import AVFoundation

public class TonetipListenerBase: NSObject {
    public var onDecodedTone: ((String, Int) -> Void)?
    private let frequency: Int

    private var audioSession: AVAudioSession!
    private var audioEngine: AVAudioEngine!
    private var converter: AVAudioConverter?
    private var desiredFormat: AVAudioFormat!

    private var decoder: DecoderMFSK?

    private var tapInstalled = false
    private let tapBufferSize: AVAudioFrameCount = 2048

    public init(frequency: Int) {
        self.frequency = frequency
        super.init()
    }

    // MARK: - Public

    public func start(completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.configureSession()
                try self.configureEngine()
                self.decoder = DecoderMFSK(speed: 2, freq: Float(self.frequency))

                try self.audioSession.setActive(true, options: [])
                try self.audioEngine.start()
                DispatchQueue.main.async { completion(nil) }
                print("🎙️ Listening at \(self.frequency) Hz")
            } catch {
                print("❌ Failed to start listener:", error)
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    public func stop() {
        removeTapIfNeeded()
        audioEngine?.stop()
        try? audioSession?.setActive(false, options: [])
        NotificationCenter.default.removeObserver(self)
        print("🛑 Stopped \(frequency)Hz")
    }

    // MARK: - Session

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playAndRecord,
            options: [
                .mixWithOthers,
                .allowBluetoothA2DP,
                .defaultToSpeaker
            ]
        )
        try session.setMode(.measurement)

        if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(builtIn)
        }

        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(1024.0 / 48_000.0)

        desiredFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false
        )!

        audioSession = session

        try session.setActive(true, options: [])

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
            return
        }

        let frames = Int(outBuf.frameLength)
        guard frames > 0, let ch0 = outBuf.floatChannelData?.pointee else { return }

        var int16 = [Int16](repeating: 0, count: frames)
        for i in 0..<frames {
            let x = max(-1.0, min(1.0, ch0[i]))
            int16[i] = Int16(x * 32767.0)
        }

        if let uarc = decoder?.processSamples(int16) {
            DispatchQueue.main.async { [weak self] in
                self?.onDecodedTone?(uarc, self?.frequency ?? 0)
            }
        }
    }


    // MARK: - Route / interruptions

    @objc private func handleRouteChange(_ n: Notification) {
        converter = nil

        if let builtIn = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? audioSession.setPreferredInput(builtIn)
        }
    }

    @objc private func handleInterruption(_ n: Notification) {
        guard let info = n.userInfo,
              let typeVal = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }

        switch type {
        case .began:
            break
        case .ended:
            try? audioSession.setActive(true)
            if !(audioEngine?.isRunning ?? false) {
                do { try audioEngine.start() } catch { }
            }
        @unknown default:
            break
        }
    }
}
