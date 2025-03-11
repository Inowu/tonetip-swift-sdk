//
//  TonetipListener.swift
//  Tonetip-ios
//
//  Created by Inowu on 07/02/25.
//

import AVFoundation

public class TonetipListenerBase: NSObject {
    public var audioEngine: AVAudioEngine?
    public var audioSession: AVAudioSession?
    public var decoder: DecoderMFSK?
    
    // Closure que se invoca cuando se detecta un tono decodificado.
    public var onDecodedTone: ((String, Int) -> Void)?
    
    private var frequency: Int
    private var lastUpdateTime = Date()
    private let updateInterval: TimeInterval = 0.5

    public init(frequency: Int) {
        self.frequency = frequency
        super.init()
        decoder = DecoderMFSK(speed: 2, freq: Float(frequency))
        initAudioSession()
    }

    public func initAudioSession() {
        audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession?.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP])
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
        audioEngine?.inputNode.removeTap(onBus: 0)
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
        let sampleRate: Double = 48000
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)!
        
        let bufferSize: AVAudioFrameCount = 2048
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] (buffer, _) in
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
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: bufferLength))
        if let decodedString = decoder?.processSamples(samples) {
            let currentTime = Date()
            if currentTime.timeIntervalSince(lastUpdateTime) > updateInterval {
                lastUpdateTime = currentTime
                DispatchQueue.main.async { [weak self] in
                    if let freq = self?.frequency {
                        self?.onDecodedTone?(decodedString, freq)
                        
                    }
                }
            }
        }
    }
}
