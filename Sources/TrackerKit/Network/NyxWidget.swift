import Foundation
import CryptoKit

/// Per-app wire-path derivation (#1 de-fingerprinting).
///
/// The fixed `/api/v1/client/init` | `/event` | `/push-token` paths are a
/// cross-app fingerprint. Instead, both this SDK and the server derive the
/// SAME believable, app-unique paths from the per-app `masterSecret` they
/// already share — no stored table, no injection, no drift.
///
/// ⚠ CONTRACT: mirrored byte-for-byte by `orchestrator/wire_paths.py` and
/// the server resolver. The `nouns` order, the `"wirepath:"` label prefix,
/// the hex slices and the `/v{ver}/{noun}/{ident}.json` format must never
/// change in just one place or live apps stop reaching the server.
enum NyxWidget {
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
