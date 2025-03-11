//
//  TonetipManager.swift
//  Tonetip-ios
//
//  Created by Inowu on 07/02/25.
//

import UIKit

public class TonetipManager {
    private var listener19k: TonetipListenerBase
    private var listener14k: TonetipListenerBase

    // Delegate que la app implementa; se notificará solo si telemetry es exitoso.
    public var delegate: TonetipDelegate?

    public init() {
        listener19k = TonetipListenerBase(frequency: 19000)
        listener14k = TonetipListenerBase(frequency: 14000)
        
        // Asignamos la closure onDecodedTone para manejar el UARC.
        listener19k.onDecodedTone = { [weak self] uarc, frequency in
            self?.handleDecodedTone(uarc: uarc, frequency: frequency)
        }
        listener14k.onDecodedTone = { [weak self] uarc, frequency in
            self?.handleDecodedTone(uarc: uarc, frequency: frequency)
        }
    }

    public func startListening() {
        listener19k.startListening()
        listener14k.startListening()
    }

    public func stopListening() {
        listener19k.stopListening()
        listener14k.stopListening()
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
        
        TelemetrySender.sendTelemetry(data: telemetry) { success in
            if success {
                DispatchQueue.main.async { [weak self] in
                    self?.delegate?.drawnTone(uarc: uarc, frequency: frequency)
                }
            } else {
                print("⚠️ Failed to send telemetry")
            }
        }
    }
}
