import Foundation
import CryptoKit












enum NyxSession {
    static let nouns = ["assets", "config", "static", "cdn", "sync",
                        "profile", "manifest", "feed", "data", "catalog"]

    static func derive(_ secret: String, _ label: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(
            for: Data(("wirepath:" + label).utf8), using: key)
        let hex = mac.map { String(format: "%02x", $0) }.joined()
        guard hex.count >= 20,
              let b0 = Int(hex.prefix(2), radix: 16),
              let b1 = Int(hex.dropFirst(2).prefix(2), radix: 16)
        else { return "" }
        let noun = nouns[b0 % nouns.count]
        let ver = (b1 % 3) + 1
        let ident = String(hex.dropFirst(4).prefix(16))
        return "/v\(ver)/\(noun)/\(ident).json"
    }
}
