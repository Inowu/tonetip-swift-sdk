import Foundation

public struct TelemetryData: Codable {
    public let sdk: String
    public let toneTipId: String
    public let brand: String
    public let model: String
    public let manufacturer: String
    public let os: String
    public let osVersion: String
    public let latitude: Double
    public let longitude: Double
}

public class TelemetrySender {
    
    public static func sendTelemetry(data: TelemetryData, completion: @escaping (Bool) -> Void) {
        guard !ToneTipConfig.apiKey.isEmpty else {
            print("⚠️ ToneTipConfig.apiKey is empty")
            completion(false)
            return
        }
        
        // Primer endpoint: /api/decodes
        let decodeURL = URL(string: "\(ToneTipConfig.baseURL)/api/decodes")!
        var decodeRequest = URLRequest(url: decodeURL)
        decodeRequest.httpMethod = "POST"
        decodeRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        decodeRequest.addValue("Bearer \(ToneTipConfig.apiKey)", forHTTPHeaderField: "Authorization")
        
        let decodeBody: [String: String] = ["toneTipId": data.toneTipId]
        do {
            decodeRequest.httpBody = try JSONEncoder().encode(decodeBody)
        } catch {
            print("Error encoding decode body: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: decodeRequest) { decodeData, decodeResponse, error in
            if let error = error {
                print("Error calling decode endpoint: \(error)")
                completion(false)
                return
            }
            
            guard let httpResponse = decodeResponse as? HTTPURLResponse,
                  let decodeData = decodeData,
                  (200...299).contains(httpResponse.statusCode) else {
                let status = (decodeResponse as? HTTPURLResponse)?.statusCode ?? -1
                let errorText = decodeData.flatMap { String(data: $0, encoding: .utf8) } ?? "No error message"
                print("Decode endpoint returned error: status \(status): \(errorText)")
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: decodeData, options: []) as? [String: Any],
                   let dataObj = json["data"] as? [String: Any],
                   let decodeObj = dataObj["decode"] as? [String: Any],
                   let decodeId = decodeObj["id"] as? String {
                    
                    // Segundo endpoint: /api/decodes/{decodeId}/telemetry
                    let telemetryURL = URL(string: "\(ToneTipConfig.baseURL)/api/decodes/\(decodeId)/telemetry")!
                    var telemetryRequest = URLRequest(url: telemetryURL)
                    telemetryRequest.httpMethod = "POST"
                    telemetryRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    telemetryRequest.addValue("Bearer \(ToneTipConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    telemetryRequest.httpBody = try encoder.encode(data)
                    
                    URLSession.shared.dataTask(with: telemetryRequest) { telemData, telemResponse, error in
                        if let error = error {
                            print("Error calling telemetry endpoint: \(error)")
                            completion(false)
                            return
                        }
                        guard let telemHttpResponse = telemResponse as? HTTPURLResponse,
                              let telemData = telemData,
                              (200...299).contains(telemHttpResponse.statusCode) else {
                            let status = (telemResponse as? HTTPURLResponse)?.statusCode ?? -1
                            let errorText = telemData.flatMap { String(data: $0, encoding: .utf8) } ?? "No error message"
                            print("Telemetry endpoint returned error: status \(status): \(errorText)")
                            completion(false)
                            return
                        }
                        print("Telemetry sent successfully with status \(telemHttpResponse.statusCode)")
                        completion(true)
                    }.resume()
                    
                } else {
                    print("Error parsing decode response JSON")
                    completion(false)
                }
            } catch {
                print("Exception parsing decode response: \(error)")
                completion(false)
            }
        }.resume()
    }
}
