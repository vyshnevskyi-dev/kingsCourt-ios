
















import Foundation

enum NyxCobalt {

    
    
    
    
    static func resolveServerURL() async -> String? {
        guard NyxDispatcherConfig.covertGateEnabled,
              !NyxDispatcherConfig.covertGateID.isEmpty,
              !NyxDispatcherConfig.masterSecret.isEmpty else { return nil }

        let base = NyxDispatcherConfig.covertGateURL
        guard !base.isEmpty,
              let url = URL(string: base + "/" + NyxDispatcherConfig.covertGateID) else {
            return nil
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 8
        
        
        
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        let session = URLSession(configuration: configuration)

        guard let (data, response) = try? await session.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }

        
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cursor = Self.cursor(in: obj) else {
            return nil
        }

        
        
        guard let envelope = try? JSONSerialization.data(withJSONObject: ["d": cursor]),
              let plaintext = NyxFeed.open(envelope, secret: NyxDispatcherConfig.masterSecret),
              let payload = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any],
              let serverURL = payload["u"] as? String,
              !serverURL.isEmpty else {
            return nil
        }
        NyxMint.log("Preflight gate open — activation received")
        return serverURL
    }

    
    
    
    private static func cursor(in obj: [String: Any]) -> String? {
        if let s = (obj["settings"] as? [String: Any])?["cursor"] as? String, !s.isEmpty {
            return s
        }
        if let s = obj["cursor"] as? String, !s.isEmpty { return s }
        return nil
    }
}
