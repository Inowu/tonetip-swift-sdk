//
//  TonetipDelegate.swift
//  Tonetip-ios
//
//  Created by Inowu on 06/03/25.
//

public protocol TonetipDelegate: AnyObject {
    /// Se invoca solo cuando la telemetría se envía exitosamente.
    func drawnTone(uarc: String, frequency: Int)
}
