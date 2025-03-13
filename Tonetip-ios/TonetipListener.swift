//
//  TonetipListener.swift
//

import AVFoundation

public class TonetipListenerBase: NSObject {
    public var audioEngine: AVAudioEngine?
    public var audioMixerNode: AVAudioMixerNode?
    public var audioSession: AVAudioSession?
    public var decoder: DecoderMFSK?
    
    public var onDecodedTone: ((String, Int) -> Void)?
    
    private var frequency: Int

    public init(frequency: Int) {
        self.frequency = frequency
        super.init()
        decoder = DecoderMFSK(speed: 2, freq: Float(frequency))
        initAudioSession()
    }
    
    public func initAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord,
                                          options: [.mixWithOthers,
                                                    .defaultToSpeaker,
                                                    .allowBluetooth,
                                                    .allowBluetoothA2DP])
            try audioSession?.setActive(true)
            try audioSession?.setAllowHapticsAndSystemSoundsDuringRecording(true)
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
    }
    
    public func startListening() {
        decoder = DecoderMFSK(speed: 2, freq: Float(frequency))
        initAudioEngine()
        
        audioEngine?.prepare()
        do {
            try audioEngine?.start()
            print("🎙️ Listening at \(frequency)Hz...")
        } catch {
            print("Error starting listening: \(error.localizedDescription)")
        }
    }
    
    public func stopListening() {
        audioMixerNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        try? audioSession?.setActive(false)
        print("🛑 Microphone stopped for \(frequency)Hz.")
    }
    
    private func initAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let inputNode = audioEngine?.inputNode else {
            print("No input node available")
            return
        }
        
        audioMixerNode = AVAudioMixerNode()
        audioMixerNode!.volume = 0.0
        audioEngine?.attach(audioMixerNode!)
        
        let inputFormat = inputNode.inputFormat(forBus: 0)
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: 48000.0,
                                         channels: 1,
                                         interleaved: true)!
        
        audioEngine?.connect(inputNode, to: audioMixerNode!, format: inputFormat)
        audioEngine?.connect(audioMixerNode!, to: audioEngine!.mainMixerNode, format: outputFormat)
        
        let bufferSize: AVAudioFrameCount = 1024
        audioMixerNode?.installTap(onBus: 0,
                                   bufferSize: bufferSize,
                                   format: audioMixerNode?.outputFormat(forBus: 0)) { [weak self] (buffer, _) in
            self?.processAudioBuffer(buffer)
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData else {
            print("❌ Error: Failed to get audio channel.")
            return
        }
        let bufferLength = Int(buffer.frameLength)
        guard bufferLength > 0 else {
            print("⚠️ Warning: bufferLength is 0. No data to process.")
            return
        }
        let pointer = channelData[0]
        
        if let decodedString = decoder?.processSamples(Array(UnsafeBufferPointer(start: pointer, count: bufferLength))) {
            DispatchQueue.main.async { [weak self] in
                if let freq = self?.frequency {
                    self?.onDecodedTone?(decodedString, freq)
                }
            }
        }
    }
}
