// NyxPlanner.swift
// Client-side HMAC-SHA256 signing for NyxFlow /client requests.
//
// Mirrors the server's canonical payload (see the backend
// security/hmac_sign module):
//     "\(bundleId).\(timestamp).".utf8 + bodyBytes
// Signature is lowercase hex; server uses constant-time compare.
//
// CryptoKit is available on iOS 13+ and ships inside the platform —
// no extra dependency to manage.

import CryptoKit
import Foundation

enum NyxPlanner {

    /// Produce the lowercase-hex HMAC-SHA256 for an NyxFlow request.
    ///
    /// Returns ``nil`` when the secret is empty — callers treat that
    /// as "signing disabled" and skip attaching the headers.
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

    /// Current Unix seconds rounded to an integer — pairs with the
    /// server's ``int(time.time())`` expectation so drift stays inside
    /// the ±5 min window.
    static func currentTimestamp() -> Int {
        Int(Date().timeIntervalSince1970)
    }
}
