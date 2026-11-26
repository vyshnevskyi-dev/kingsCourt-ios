




























import CryptoKit
import Foundation

enum NyxFeed {

    
    private static func key(_ secret: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(secret.utf8)))
    }

    
    
    
    static func seal(_ plaintext: Data, secret: String) -> Data? {
        guard !secret.isEmpty else { return nil }
        guard let box = try? AES.GCM.seal(plaintext, using: key(secret)),
              let combined = box.combined else {
            return nil
        }
        let envelope = ["d": combined.base64EncodedString()]
        return try? JSONSerialization.data(withJSONObject: envelope)
    }

    
    
    
    static func open(_ data: Data, secret: String) -> Data? {
        guard !secret.isEmpty else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj.count == 1,
              let b64 = obj["d"] as? String,
              let combined = Data(base64Encoded: b64),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(box, using: key(secret)) else {
            return nil
        }
        return plaintext
    }
}
