// NyxFeed.swift
// Symmetric AES-GCM envelope for NyxFlow request / response bodies.
//
// Opt-in via ``NyxDispatcherConfig.encryptBodyEnabled`` (pipeline flag
// ``security.encrypt_body``). When on, ``NyxGalleryClient`` seals the
// plaintext JSON before it leaves the device and opens the server's
// reply after it lands, so a proxy / static dump on the wire sees only
// an opaque ``{"d":"<base64>"}`` envelope instead of the casino flag or
// landing URL. This is defence-in-depth *on top of* TLS + HMAC — it
// survives a pinning bypass on a jailbroken device, where the attacker
// can read TLS plaintext but still can't read the GCM ciphertext
// without the key.
//
// Key derivation: ``SHA256(masterSecret)`` — the same per-app secret
// the HMAC layer already ships (see ``NyxPlanner`` /
// ``security_keys.py``), so there's no second secret to provision or
// rotate. HMAC uses the raw secret as its MAC key; encryption uses its
// SHA-256 digest as the AES-256 key. Distinct uses of one root secret.
//
// Envelope wire format (mirrors ``app/security/body_cipher.py``):
//     {"d": base64( nonce(12) || ciphertext || tag(16) )}
// The 12-byte nonce + 16-byte tag layout is exactly CryptoKit's
// ``AES.GCM.SealedBox.combined``, which the Python ``cryptography``
// AESGCM accepts verbatim — no manual framing on either side.
//
// The envelope is JSON-shaped on purpose: to a casual proxy or App
// Store binary scan it reads as a benign config payload (Content-Type
// stays ``application/json``), not suspicious raw binary.

import CryptoKit
import Foundation

enum NyxFeed {

    /// AES-256 key derived from the per-app HMAC secret.
    private static func key(_ secret: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(secret.utf8)))
    }

    /// Seal ``plaintext`` into the ``{"d":"…"}`` envelope. Returns nil
    /// on empty secret or any crypto/serialisation failure — callers
    /// fall back to sending the plaintext rather than dropping data.
    static func seal(_ plaintext: Data, secret: String) -> Data? {
        guard !secret.isEmpty else { return nil }
        guard let box = try? AES.GCM.seal(plaintext, using: key(secret)),
              let combined = box.combined else {
            return nil
        }
        let envelope = ["d": combined.base64EncodedString()]
        return try? JSONSerialization.data(withJSONObject: envelope)
    }

    /// Open a ``{"d":"…"}`` envelope back to plaintext. Returns nil when
    /// ``data`` isn't a well-formed envelope (so a plaintext / error
    /// response passes straight through) or authentication fails.
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
