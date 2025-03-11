//
//  ToneTipConfig.swift
//  Tonetip-ios
//
//  Created by Inowu on [Fecha].
//

public struct ToneTipConfig {
    public static var apiKey: String = ""
    public static var isSandbox: Bool = false
        
        public static var baseURL: String {
            return isSandbox ? "https://tonetip-sb.inowu.dev" : "https://tonetip.inowu.dev"
        }
}
