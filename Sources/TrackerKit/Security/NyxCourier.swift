










import CryptoKit
import Foundation

enum NyxCourier {

    
    
    
    
    static func sign(
        secret: String,
        bundleID: String,
        timestamp: Int,
        body: Data
    ) -> String? {
        guard !secret.isEmpty else { return nil }
        guard !bundleID.isEmpty else { return nil }

        let prefix = "\(bundleID).\(timestamp).".data(using: .utf8) ?? Data()
        var payload = Data()
        payload.append(prefix)
        payload.append(body)

        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    
    
    
    static func currentTimestamp() -> Int {
        Int(Date().timeIntervalSince1970)
    }
}
