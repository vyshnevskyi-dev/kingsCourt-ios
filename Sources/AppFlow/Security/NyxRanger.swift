// NyxRanger.swift
// Compile-time string obfuscation for the NyxFlow SDK.
//
// The AppFactory pipeline (``inject.py``, opt-in via
// ``security.obfuscate_strings``) XOR-encodes the backend domain and
// the API path suffixes against a per-build random key and bakes the
// byte arrays into ``NyxDispatcherConfig.vault`` / ``NyxDispatcherConfig.vaultKey``. The
// plaintext never appears in the shipped binary, so a ``strings`` /
// Hopper / IDA pass over the IPA can't recover ``wildcherry.cloud`` or
// the ``/api/v1/client/init`` route — the single most identifying
// indicator linking a build to our infra.
//
// This is *static*-analysis evasion only: a runtime dump still sees the
// revealed string in memory. That's the intended trade-off (see the
// security note in CHERRY_FLOW_DESIGN.md) — it defeats App Store's
// automated binary scan and casual reversing, not a live Frida hook.
//
// When the vault is empty (default SDK / dev / unit tests) callers fall
// back to the plaintext ``*Plain`` constants in ``NyxDispatcherConfig`` → the SDK
// behaves byte-for-byte as before obfuscation existed.

import Foundation

enum NyxRanger {

    /// XOR-deobfuscate ``blob`` with the repeating ``key`` and decode
    /// the result as UTF-8.
    ///
    /// Returns ``nil`` when either input is empty — the caller treats
    /// that as "obfuscation disabled" and uses its plaintext fallback.
    /// Decoding is lenient (``String(decoding:as:)`` never throws); a
    /// corrupt blob yields garbage rather than a crash, which is the
    /// safe failure mode for a network-path constant.
    static func reveal(_ blob: [UInt8], key: [UInt8]) -> String? {
        guard !blob.isEmpty, !key.isEmpty else { return nil }
        var out = [UInt8]()
        out.reserveCapacity(blob.count)
        for i in 0..<blob.count {
            out.append(blob[i] ^ key[i % key.count])
        }
        return String(decoding: out, as: UTF8.self)
    }
}
