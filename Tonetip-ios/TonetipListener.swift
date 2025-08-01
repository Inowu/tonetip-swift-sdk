//
//  TonetipListenerBase.swift
//

import AVFoundation

public class TonetipListenerBase: NSObject {
    public var onDecodedTone: ((String, Int) -> Void)?
    private let frequency: Int

    private var audioSession: AVAudioSession?
    private var audioEngine: AVAudioEngine?
    private var audioMixerNode: AVAudioMixerNode?
    private var decoder: DecoderMFSK?

    public init(frequency: Int) {
        self.frequency = frequency
        super.init()
    }

    /// Inicia todo el flujo: audio session, engine, decoder y arranque.
    public func start(completion: @escaping (Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.configureAudioSession()
                self.configureAudioEngine()
                
                // ← Aquí creas el decoder NUEVO
                self.decoder = DecoderMFSK(speed: 2, freq: Float(self.frequency))

                try self.audioSession?.setActive(true)
                try self.audioEngine?.start()
                print("🎙️ Listening at \(self.frequency)Hz")
                DispatchQueue.main.async { completion(nil) }
            } catch {
                print("❌ Failed to start listener:", error)
                DispatchQueue.main.async { completion(error) }
            }
        }
    }

    public func stop() {
        audioMixerNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        try? audioSession?.setActive(false)
        print("🛑 Stopped \(frequency)Hz")
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setMode(.measurement)
        if let bt = session.availableInputs?.first(where: { $0.portType == .bluetoothHFP }) {
            try session.setPreferredInput(bt)
            print("🎧 Using Bluetooth HFP: \(bt.portName)")
        }
        audioSession = session
    }

    private func configureAudioEngine() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let mixer = AVAudioMixerNode()
        mixer.volume = 0
        engine.attach(mixer)

        // Formatos
        let inFmt = input.inputFormat(forBus: 0)
        let targetFmt = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                      sampleRate: 48_000,
                                      channels: 1,
                                      interleaved: true)!

        // Conecta input → mixer → mainMixer
        engine.connect(input, to: mixer, format: inFmt)
        engine.connect(mixer, to: engine.mainMixerNode, format: targetFmt)

        // Tap **en el mixer**, usando el formato FINAL (targetFmt)
        mixer.installTap(onBus: 0,
                         bufferSize: 1024,
                         format: targetFmt) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        audioEngine = engine
        audioMixerNode = mixer
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let ptr = buffer.int16ChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: ptr, count: count))
        if let uarc = decoder?.processSamples(samples) {
            DispatchQueue.main.async {
                self.onDecodedTone?(uarc, self.frequency)
            }
        }
    }
}
