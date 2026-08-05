// NetworkModels.swift
// Request and response models for backend communication

import Foundation

// MARK: - Init Request

struct NyxLibraryRequest: Codable {

    let schema: Int
    let app: NyxRender
    let device: Device
    let privacy: Privacy
    let ids: Identifiers
    let attribution: Attribution?
    let push: NyxAccount?
    /// Native device fingerprint for Cherry Flow probabilistic matching.
    /// Optional — populated only for ``NyxDispatcherConfig.cherryFlowEnabled``
    /// builds; nil for ``base`` apps, so the synthesised encoder omits
    /// the ``fingerprint`` key entirely (request shape unchanged).
    let fingerprint: Fingerprint?

    struct NyxRender: Codable {
        let bundleId: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle_id"
            case version
        }
    }

    struct Device: Codable {
        let language: String
        let timezone: String
        let region: String
    }

    struct Privacy: Codable {
        let att: String
    }

    struct Identifiers: Codable {
        let internalId: String
        let idfa: String?

        enum CodingKeys: String, CodingKey {
            case internalId = "internal_id"
            case idfa
        }
    }

    struct Attribution: Codable {
        let appsflyerId: String?

        enum CodingKeys: String, CodingKey {
            case appsflyerId = "appsflyer_id"
        }
    }

    struct NyxAccount: Codable {
        let token: String?
    }

    /// Native fingerprint mirror of the web collector's payload. Field
    /// names match the server schema (CHERRY_FLOW_DESIGN.md §5):
    /// ``model`` (utsname machine), logical ``screen_w``/``screen_h``
    /// in points, ``screen_scale`` (≈ web devicePixelRatio), and
    /// ``os_version`` (major.minor).
    struct Fingerprint: Codable {
        let model: String
        let screenW: Int
        let screenH: Int
        let screenScale: Double
        let osVersion: String

        enum CodingKeys: String, CodingKey {
            case model
            case screenW = "screen_w"
            case screenH = "screen_h"
            case screenScale = "screen_scale"
            case osVersion = "os_version"
        }
    }

    // MARK: - Factory

    @MainActor
    static func create(
        uniqueId: String,
        hasATT: Bool = true,
        appsflyerId: String? = nil,
        pushToken: String? = nil
    ) -> NyxLibraryRequest {
        let device = NyxCometHelper.shared

        // ATT status: if app doesn't have ATT permission, send "unavailable"
        let attStatus = hasATT ? device.trackingStatusString : "unavailable"
        let idfa = hasATT ? device.advertisingID : nil

        // Cherry Flow native fingerprint — built only for cherry_flow
        // builds. nil for base apps → omitted from the JSON entirely.
        let fingerprint: Fingerprint? = NyxDispatcherConfig.cherryFlowEnabled
            ? Fingerprint(
                model: device.deviceModel,
                screenW: device.screenWidthPoints,
                screenH: device.screenHeightPoints,
                screenScale: device.screenScale,
                osVersion: device.osVersion
            )
            : nil

        return NyxLibraryRequest(
            schema: 1,
            app: NyxRender(
                bundleId: device.bundleID,
                version: device.appVersion
            ),
            device: Device(
                language: "\(device.language)-\(device.region)",
                timezone: device.timezone,
                region: device.region
            ),
            privacy: Privacy(
                att: attStatus
            ),
            ids: Identifiers(
                internalId: uniqueId,
                idfa: idfa
            ),
            attribution: appsflyerId != nil ? Attribution(appsflyerId: appsflyerId) : nil,
            push: pushToken != nil ? NyxAccount(token: pushToken) : nil,
            fingerprint: fingerprint
        )
    }
}

// MARK: - Blocked Payload

/// Server-triggered fullscreen overlay for blocked apps.
///
/// When ``NyxLibraryResponse.blocked`` is non-nil, the SDK renders a
/// non-dismissible screen with a single button opening ``buttonURL``
/// (typically an App Store deep link to a replacement app) and
/// ignores every other response field (``result``, ``update``,
/// ``icon``). ``sticky=true`` tells the client to cache the payload
/// and keep showing the overlay on cold launches even before the
/// next ``/init`` completes.
struct NyxForge: Codable, Equatable {
    let title: String
    let message: String
    let buttonText: String
    let buttonURL: String
    let sticky: Bool

    enum CodingKeys: String, CodingKey {
        case title
        case message
        case buttonText = "button_text"
        case buttonURL = "button_url"
        case sticky
    }

    /// Parsed destination URL. Nil on malformed server payload (we
    /// still render the overlay; the button just logs an error on tap
    /// rather than navigating somewhere wrong).
    var url: URL? { URL(string: buttonURL) }
}

// MARK: - Init Response

struct NyxLibraryResponse: Codable {

    /// Casino URL if mode is Casino; null for Native mode
    let result: String?

    /// Prompt configuration (required)
    let prompts: NyxNexusConfig

    /// Update configuration (optional)
    let update: NyxStageConfig?

    /// Alternate icon name to set (e.g. "icon_white", "icon_dark", "icon_bonus")
    /// nil = keep current icon, "" = reset to primary
    let icon: String?

    /// Sticky per-device mode assignment issued by the server on first
    /// ``/client/init``. ``NyxGalleryClient`` persists this via
    /// ``NyxProfile.flowToken`` (write-once) on first receipt.
    /// Absent on old server deploys → decoding just leaves it nil and
    /// the existing legacy flow continues unchanged.
    let flowToken: String?

    /// Server-triggered Fortune Wheel overlay config. Nil / show=false
    /// → client skips the overlay entirely (default). When the operator
    /// turns it on in admin, this object drives delay, visual target,
    /// CTA label, and the landing URL opened in SFSafariViewController
    /// after the swipe confirmation.
    let fortuneWheel: NyxEchoConfig?

    /// Remote kill-switch overlay for blocked apps. When non-nil the
    /// router transitions to ``NyxDispatcherState.blocked`` and renders a
    /// fullscreen non-dismissible screen regardless of the other
    /// fields. Nil on every old-server response (backward compat).
    let blocked: NyxForge?

    /// all_high_risk + client mode (#4). When present, the WebView should
    /// follow the ``result`` redirect chain and load ``stubURL`` if fewer
    /// than ``minRedirects`` hops happen (no real offer for this geo).
    /// Nil on every normal response — no behaviour change.
    let redirectPolicy: NyxVertex?

    enum CodingKeys: String, CodingKey {
        case result
        case prompts
        case update
        case icon
        case flowToken = "cohort_token"
        case fortuneWheel = "fortune_wheel"
        case blocked = "ban_gate"
        case redirectPolicy = "redirect_policy"
    }

    // MARK: - Redirect Policy

    struct NyxVertex: Codable {
        let minRedirects: Int
        let stubURL: String?
        let follow: Bool?

        enum CodingKeys: String, CodingKey {
            case minRedirects = "min_redirects"
            case stubURL = "stub_url"
            case follow
        }

        var stub: URL? { stubURL.flatMap(URL.init) }
        var shouldFollow: Bool { follow ?? true }
    }

    // MARK: - Fortune Wheel

    struct NyxEchoConfig: Codable {
        /// Master toggle — server's `false` is treated the same as nil.
        let show: Bool?
        /// Seconds to wait after /init before presenting the overlay.
        /// Works in any router state (native or webView) because the
        /// overlay layer renders above both.
        let delaySec: Int?
        /// Where the wheel visually stops, 0-1000.
        let targetValue: Int?
        /// Post-spin CTA label. Operator-controlled (e.g.
        /// "TO WIN THE GOLDEN TICKET", "TO HIT THE JACKPOT").
        let ctaLabel: String?
        /// Landing URL the user is taken to after swiping the CTA.
        /// Host site typically has its own "open in partner app" button —
        /// we only need to hand off cleanly.
        let ctaLandingURL: String?
        /// How the landing URL is opened: ``"safari"`` (SFSafariViewController,
        /// default) or ``"webview"`` (dismiss Fortune Wheel → open URL in
        /// the app's WKWebView surface). Missing / nil → Safari.
        let landingMode: String?
        /// Headline on the spin screen (server-overridable; falls back
        /// to the SDK default when nil/empty).
        let title: String?
        /// Sub-headline on the spin screen.
        let subtitle: String?
        /// Headline on the post-spin result screen ("Congratulations!").
        let resultTitle: String?
        /// Wheel face labels, e.g. ["100","250",…]. Any count ≥2; the
        /// SDK cycles its colour palette. nil/empty → SDK default set.
        let segments: [String]?

        enum CodingKeys: String, CodingKey {
            case show
            case delaySec = "delay_sec"
            case targetValue = "target_value"
            case ctaLabel = "cta_label"
            case ctaLandingURL = "cta_landing_url"
            case landingMode = "landing_mode"
            case title
            case subtitle
            case resultTitle = "result_title"
            case segments
        }

        /// Convenience: whether this config has the minimum viable
        /// contents to actually present.
        var isEnabled: Bool {
            (show ?? false) && targetValue != nil
        }
    }

    struct NyxNexusConfig: Codable {
        /// Delay before rating prompt (seconds)
        let rateDelaySec: Int

        /// Delay before push permission prompt (seconds)
        let pushDelaySec: Int

        enum CodingKeys: String, CodingKey {
            case rateDelaySec = "rate_delay_sec"
            case pushDelaySec = "push_delay_sec"
        }
    }

    struct NyxStageConfig: Codable {
        /// Minimum supported version
        let minVersion: String?

        /// Latest available version
        let latestVersion: String?

        /// Update mode: "soft" or "force"
        let mode: String?

        /// App Store URL
        let appstoreUrl: String?

        enum CodingKeys: String, CodingKey {
            case minVersion = "min_version"
            case latestVersion = "latest_version"
            case mode
            case appstoreUrl = "appstore_url"
        }
    }

    // MARK: - Computed

    /// Should show WebView with casino URL
    var shouldShowWebView: Bool {
        result != nil && !result!.isEmpty
    }

    /// Should show native app content
    var shouldShowNative: Bool {
        result == nil || result!.isEmpty
    }

    /// WebView URL
    var webURL: URL? {
        result.flatMap(URL.init)
    }

    /// Push delay as TimeInterval
    var pushDelay: TimeInterval {
        TimeInterval(prompts.pushDelaySec)
    }

    /// Rate delay as TimeInterval
    var rateDelay: TimeInterval {
        TimeInterval(prompts.rateDelaySec)
    }

    /// Should force update
    var shouldForceUpdate: Bool {
        guard let updateConfig = update,
              updateConfig.mode == "force",
              let minVersion = updateConfig.minVersion else {
            return false
        }
        let currentVersion = NyxCometHelper.shared.appVersion
        return currentVersion.compare(minVersion, options: .numeric) == .orderedAscending
    }

    /// Should show soft update prompt
    var shouldSoftUpdate: Bool {
        guard let updateConfig = update,
              updateConfig.mode == "soft",
              let minVersion = updateConfig.minVersion else {
            return false
        }
        let currentVersion = NyxCometHelper.shared.appVersion
        return currentVersion.compare(minVersion, options: .numeric) == .orderedAscending
    }

    /// App Store URL
    var storeURL: URL? {
        update?.appstoreUrl.flatMap(URL.init)
    }
}

// MARK: - Push Token Upload

/// Body for ``POST /api/v1/client/push-token`` — the dedicated
/// upload path for APNs tokens.
///
/// Previously the SDK piggybacked push token updates onto a repeat
/// ``/init`` call, which meant every first install produced two
/// full decision-pipeline runs on the server just to attach one
/// string. The standalone route keeps ``/init`` idempotent and
/// lets the server derive ``push_enabled`` from the auth status
/// the client reports.
struct NyxKernelRequest: Codable {

    let schema: Int
    let app: NyxRender
    let ids: Identifiers
    let push: NyxRunner

    struct NyxRender: Codable {
        let bundleId: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle_id"
            case version
        }
    }

    struct Identifiers: Codable {
        let internalId: String

        enum CodingKeys: String, CodingKey {
            case internalId = "internal_id"
        }
    }

    struct NyxRunner: Codable {
        /// Hex-encoded APNs device token.
        let token: String
        /// ``UNAuthorizationStatus`` mapped to its iOS-debug string.
        /// Optional on the wire but we always send it so the server
        /// can compute ``push_enabled`` deterministically.
        let authStatus: String?
        /// "production" / "sandbox". Purely informational today —
        /// server uses its own per-app ``apns_environment`` setting
        /// at send time — but lets us spot build-env mismatches in
        /// logs without an extra round trip.
        let environment: String?

        enum CodingKeys: String, CodingKey {
            case token
            case authStatus = "auth_status"
            case environment
        }
    }

    // MARK: - Factory

    @MainActor
    static func create(
        token: String,
        authStatus: String?,
        environment: String? = nil
    ) -> NyxKernelRequest {
        let device = NyxCometHelper.shared
        return NyxKernelRequest(
            schema: 1,
            app: NyxRender(
                bundleId: device.bundleID,
                version: device.appVersion
            ),
            ids: Identifiers(
                internalId: NyxProfile.shared.uniqueID
            ),
            push: NyxRunner(
                token: token,
                authStatus: authStatus,
                environment: environment
            )
        )
    }
}

struct NyxKernelResponse: Codable {
    let ok: Bool
    let pushEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case ok
        case pushEnabled = "push_enabled"
    }
}

// MARK: - Event Request

struct NyxAtlasRequest: Codable {

    let schema: Int
    let app: NyxRender
    let ids: NyxPointer
    let event: NyxLayout

    struct NyxRender: Codable {
        let bundleId: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle_id"
            case version
        }
    }

    struct NyxPointer: Codable {
        let internalId: String

        enum CodingKeys: String, CodingKey {
            case internalId = "internal_id"
        }
    }

    struct NyxLayout: Codable {
        /// Event name
        let name: String

        /// Unix timestamp in seconds
        let ts: Int

        /// Additional event properties
        let props: [String: NyxCrestValue]?
    }

    // MARK: - Factory

    @MainActor
    static func create(
        name: String,
        uniqueId: String,
        properties: [String: Any]? = nil
    ) -> NyxAtlasRequest {
        let device = NyxCometHelper.shared

        return NyxAtlasRequest(
            schema: 1,
            app: NyxRender(
                bundleId: device.bundleID,
                version: device.appVersion
            ),
            ids: NyxPointer(
                internalId: uniqueId
            ),
            event: NyxLayout(
                name: name,
                ts: Int(Date().timeIntervalSince1970),
                props: properties?.mapValues { NyxCrestValue($0) }
            )
        )
    }
}

// MARK: - Standard Events

extension NyxAtlasRequest {
    enum NyxCabin: String {
        // Rate events
        case rateSheetShown = "rate_sheet_shown"
        case rateSliderCompleted = "rate_slider_completed"
        case rateSheetClosed = "rate_sheet_closed"
        /// Rating >= 4 → SKStoreReviewController.requestReview was invoked.
        /// Actual prompt display is still up to Apple's system throttle.
        case rateStoreReviewRequested = "rate_store_review_requested"
        /// Rating <= 3 → captured internally; no App Store prompt shown.
        case rateLowCaptured = "rate_low_captured"

        // Push events
        case pushPromptShown = "push_prompt_shown"
        case pushPromptAccepted = "push_prompt_accepted"
        case pushPromptDeclined = "push_prompt_declined"

        // Icon events
        case iconBannerShown = "icon_banner_shown"
        case iconSwipeCompleted = "icon_swipe_completed"
        case iconBannerExpired = "icon_banner_expired"

        // Fortune wheel events
        case fortuneWheelShown = "fortune_wheel_shown"
        case fortuneWheelSpun = "fortune_wheel_spun"
        case fortuneWheelCtaTapped = "fortune_wheel_cta_tapped"
        case fortuneWheelClosed = "fortune_wheel_closed"

        // Deep link events
        /// Fired from ``NyxMeadowRouter`` when an incoming URL matches
        /// ``NyxDispatcherConfig.deepLinkScheme`` or ``universalDomains``. Props
        /// include ``source`` (``url_scheme`` / ``universal_link``), the
        /// raw ``url``, optional ``landing`` override, and any
        /// attribution params forwarded verbatim (``af_*`` / ``utm_*`` /
        /// ``click_*``) so the backend can correlate campaigns without
        /// an extra attribution SDK.
        case deepLinkOpened = "deep_link_opened"

        // Push notification events
        /// User tapped a push notification. Props: ``action`` (native /
        /// in_app_webview / external), ``url`` (for webview / external),
        /// ``deeplink`` (for native). Lets the campaign dashboard
        /// measure real engagement (tapped-through vs merely delivered).
        case pushTapped = "push_tapped"
    }
}

// MARK: - AnyCodable Helper

struct NyxCrestValue: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([NyxCrestValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: NyxCrestValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]: try container.encode(array.map { NyxCrestValue($0) })
        case let dict as [String: Any]: try container.encode(dict.mapValues { NyxCrestValue($0) })
        default: try container.encodeNil()
        }
    }
}
