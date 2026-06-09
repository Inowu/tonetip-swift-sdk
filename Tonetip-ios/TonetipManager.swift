//
//  TonetipManager.swift
//

import UIKit

public class TonetipManager {
    private var listener: TonetipListenerBase
    public var delegate: TonetipDelegate?

    public init() {
        listener = TonetipListenerBase(frequencies: [19000, 14000])

        listener.debugEnabled = false
        listener.forceBuiltInMic = false

        listener.onDecodedTone = { [weak self] uarc, frequency in
            self?.handleDecodedTone(uarc: uarc, frequency: frequency)
        }
    }

    public func startListening(completion: @escaping (Error?) -> Void) {
        listener.start { error in
            if let e = error {
                print("❌ TonetipManager failed to start:", e)
            } else {
                print("✅ TonetipManager listening on 14 kHz & 19 kHz")
            }
            completion(error)
        }
    }

    public func stopListening() {
        listener.stop()
        print("🛑 TonetipManager stopped listener")
    }

    private func handleDecodedTone(uarc: String, frequency: Int) {
        let device = UIDevice.current
        let telemetry = TelemetryData(
            sdk: "1.0.0",
            toneTipId: uarc,
            brand: "Apple",
            model: device.model,
            manufacturer: "Apple",
            os: device.systemName,
            osVersion: device.systemVersion,
            latitude: 0.0,
            longitude: 0.0
        )

        DispatchQueue.main.async { [weak self] in
            self?.delegate?.drawnTone(uarc: uarc, frequency: frequency)
        }
        TelemetrySender.sendTelemetry(data: telemetry) { _ in }
    }
}
