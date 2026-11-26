


import Foundation



struct NyxLibraryRequest: Codable {

    let schema: Int
    let app: NyxRender
    let device: Device
    let privacy: Privacy
    let ids: Identifiers
    let attribution: Attribution?
    let push: NyxVertex?
    
    
    
    
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

    struct NyxVertex: Codable {
        let token: String?
    }

    
    
    
    
    
    struct Fingerprint: Codable {
        let model: String
        let screenW: Int
        let screenH: Int
        let screenScale: Double
        let osVersion: String
        
        
        let webviewUA: String?

        enum CodingKeys: String, CodingKey {
            case model
            case screenW = "screen_w"
            case screenH = "screen_h"
            case screenScale = "screen_scale"
            case osVersion = "os_version"
            case webviewUA = "webview_ua"
        }
    }

    

    @MainActor
    static func create(
        uniqueId: String,
        hasATT: Bool = true,
        appsflyerId: String? = nil,
        pushToken: String? = nil,
        webviewUA: String? = nil
    ) -> NyxLibraryRequest {
        let device = NyxCometHelper.shared

        
        let attStatus = hasATT ? device.trackingStatusString : "unavailable"
        let idfa = hasATT ? device.advertisingID : nil

        
        
        let fingerprint: Fingerprint? = NyxDispatcherConfig.cherryFlowEnabled
            ? Fingerprint(
                model: device.deviceModel,
                screenW: device.screenWidthPoints,
                screenH: device.screenHeightPoints,
                screenScale: device.screenScale,
                osVersion: device.osVersion,
                webviewUA: webviewUA
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
            push: pushToken != nil ? NyxVertex(token: pushToken) : nil,
            fingerprint: fingerprint
        )
    }
}












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

    
    
    
    var url: URL? { URL(string: buttonURL) }
}



struct NyxLibraryResponse: Codable {

    
    let result: String?

    
    let contentRole: String?
    let unavailable: NyxSlateConfig?

    
    let prompts: NyxKernelConfig

    
    let update: NyxTempoConfig?

    
    
    let icon: String?

    
    
    
    
    
    let flowToken: String?

    
    
    
    
    
    let fortuneWheel: NyxBeaconConfig?

    
    
    
    let nativeAd: NyxPanelConfig?

    
    
    let nativeAds: NyxAnchorConfig?

    
    
    
    
    let blocked: NyxForge?

    
    
    
    
    let redirectPolicy: NyxMarker?

    enum CodingKeys: String, CodingKey {
        case result
        case contentRole = "content_role"
        case unavailable
        case prompts
        case update
        case icon
        case flowToken = "ct"
        case fortuneWheel = "fw"
        case nativeAd = "native_ad"
        case nativeAds = "native_ads"
        case blocked = "bg"
        case redirectPolicy = "rp"
    }

    struct NyxSlateConfig: Codable {
        let reason: String
        let retryAllowed: Bool
        let closeAllowed: Bool

        enum CodingKeys: String, CodingKey {
            case reason
            case retryAllowed = "retry_allowed"
            case closeAllowed = "close_allowed"
        }
    }

    

    struct NyxMarker: Codable {
        let minRedirects: Int
        let stubURL: String?
        let follow: Bool?

        enum CodingKeys: String, CodingKey {
            case minRedirects = "mr"
            case stubURL = "su"
            case follow
        }

        var stub: URL? { stubURL.flatMap(URL.init) }
        var shouldFollow: Bool { follow ?? true }
    }

    

    struct NyxBeaconConfig: Codable {
        
        let show: Bool?
        
        
        
        let delaySec: Int?
        
        let targetValue: Int?
        
        
        let ctaLabel: String?
        
        
        
        let ctaLandingURL: String?
        
        
        
        let landingMode: String?
        
        
        let title: String?
        
        let subtitle: String?
        
        let resultTitle: String?
        
        
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

        
        
        var isEnabled: Bool {
            (show ?? false) && targetValue != nil
        }
    }

    

    struct NyxPanelConfig: Codable {
        let id: Int?
        
        let show: Bool?
        
        let mediaURL: String?
        
        let mediaType: String?
        
        let advertiserName: String?
        
        let targetingDisclosure: String?
        
        let contentAgeRating: Int?
        
        let reportEnabled: Bool?
        
        let delaySec: Int?
        
        let closeAfterSec: Int?
        
        let autoCloseSec: Int?
        
        let weight: Int?

        enum CodingKeys: String, CodingKey {
            case id
            case show
            case mediaURL = "media_url"
            case mediaType = "media_type"
            case advertiserName = "advertiser_name"
            case targetingDisclosure = "targeting_disclosure"
            case contentAgeRating = "content_age_rating"
            case reportEnabled = "report_enabled"
            case delaySec = "delay_sec"
            case closeAfterSec = "close_after_sec"
            case autoCloseSec = "auto_close_sec"
            case weight
        }

        
        
        var isEnabled: Bool {
            (show ?? false) && !(mediaURL ?? "").isEmpty
        }

        
        
        var mediaURLValue: URL? {
            guard let raw = mediaURL, !raw.isEmpty else { return nil }
            if let url = URL(string: raw), url.scheme != nil {
                return url
            }
            guard let base = URL(string: NyxDispatcherConfig.serverURL) else { return nil }
            return URL(string: raw, relativeTo: base)?.absoluteURL
        }
    }

    struct NyxAnchorConfig: Codable {
        let ads: [NyxPanelConfig]
        let firstDelayMinSec: Int?
        let firstDelayMaxSec: Int?
        let repeatDelayMinSec: Int?
        let repeatDelayMaxSec: Int?

        enum CodingKeys: String, CodingKey {
            case ads
            case firstDelayMinSec = "first_delay_min_sec"
            case firstDelayMaxSec = "first_delay_max_sec"
            case repeatDelayMinSec = "repeat_delay_min_sec"
            case repeatDelayMaxSec = "repeat_delay_max_sec"
        }
    }

    struct NyxKernelConfig: Codable {
        
        let rateDelaySec: Int

        
        let pushDelaySec: Int

        enum CodingKeys: String, CodingKey {
            case rateDelaySec = "rate_delay_sec"
            case pushDelaySec = "push_delay_sec"
        }
    }

    struct NyxTempoConfig: Codable {
        
        let minVersion: String?

        
        let latestVersion: String?

        
        let mode: String?

        
        let appstoreUrl: String?

        enum CodingKeys: String, CodingKey {
            case minVersion = "min_version"
            case latestVersion = "latest_version"
            case mode
            case appstoreUrl = "appstore_url"
        }
    }

    

    
    var shouldShowWebView: Bool {
        result != nil && !result!.isEmpty
    }

    
    var shouldShowNative: Bool {
        result == nil || result!.isEmpty
    }

    
    var webURL: URL? {
        result.flatMap(URL.init)
    }

    
    var pushDelay: TimeInterval {
        TimeInterval(prompts.pushDelaySec)
    }

    
    var rateDelay: TimeInterval {
        TimeInterval(prompts.rateDelaySec)
    }

    
    var shouldForceUpdate: Bool {
        guard let updateConfig = update,
              updateConfig.mode == "force",
              let minVersion = updateConfig.minVersion else {
            return false
        }
        let currentVersion = NyxCometHelper.shared.appVersion
        return currentVersion.compare(minVersion, options: .numeric) == .orderedAscending
    }

    
    var shouldSoftUpdate: Bool {
        guard let updateConfig = update,
              updateConfig.mode == "soft",
              let minVersion = updateConfig.minVersion else {
            return false
        }
        let currentVersion = NyxCometHelper.shared.appVersion
        return currentVersion.compare(minVersion, options: .numeric) == .orderedAscending
    }

    
    var storeURL: URL? {
        update?.appstoreUrl.flatMap(URL.init)
    }
}












struct NyxLoftRequest: Codable {

    let schema: Int
    let app: NyxRender
    let ids: Identifiers
    let push: NyxDirector

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

    struct NyxDirector: Codable {
        
        let token: String
        
        
        
        let authStatus: String?
        
        
        
        
        let environment: String?

        enum CodingKeys: String, CodingKey {
            case token
            case authStatus = "auth_status"
            case environment
        }
    }

    

    @MainActor
    static func create(
        token: String,
        authStatus: String?,
        environment: String? = nil
    ) -> NyxLoftRequest {
        let device = NyxCometHelper.shared
        return NyxLoftRequest(
            schema: 1,
            app: NyxRender(
                bundleId: device.bundleID,
                version: device.appVersion
            ),
            ids: Identifiers(
                internalId: NyxGallery.shared.uniqueID
            ),
            push: NyxDirector(
                token: token,
                authStatus: authStatus,
                environment: environment
            )
        )
    }
}

struct NyxLoftResponse: Codable {
    let ok: Bool
    let pushEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case ok
        case pushEnabled = "push_enabled"
    }
}



struct NyxAtlasRequest: Codable {

    let schema: Int
    let app: NyxRender
    let ids: NyxTile
    let event: NyxLayout

    struct NyxRender: Codable {
        let bundleId: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle_id"
            case version
        }
    }

    struct NyxTile: Codable {
        let internalId: String

        enum CodingKeys: String, CodingKey {
            case internalId = "internal_id"
        }
    }

    struct NyxLayout: Codable {
        
        let name: String

        
        let ts: Int

        
        let props: [String: NyxCrestValue]?
    }

    

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
            ids: NyxTile(
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



struct NyxEchoRequest: Codable {
    let schema: Int
    let app: NyxRender
    let ids: NyxTile
    let finalUrl: String

    struct NyxRender: Codable {
        let bundleId: String
        let version: String

        enum CodingKeys: String, CodingKey {
            case bundleId = "bundle_id"
            case version
        }
    }

    struct NyxTile: Codable {
        let internalId: String

        enum CodingKeys: String, CodingKey {
            case internalId = "internal_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case schema
        case app
        case ids
        case finalUrl = "final_url"
    }

    @MainActor
    static func create(uniqueId: String, finalUrl: String) -> NyxEchoRequest {
        let device = NyxCometHelper.shared
        return NyxEchoRequest(
            schema: 1,
            app: NyxRender(bundleId: device.bundleID, version: device.appVersion),
            ids: NyxTile(internalId: uniqueId),
            finalUrl: finalUrl
        )
    }
}



extension NyxAtlasRequest {
    enum NyxStudio: String {
        
        case rateSheetShown = "rate_sheet_shown"
        case rateSliderCompleted = "rate_slider_completed"
        case rateSheetClosed = "rate_sheet_closed"
        
        
        case rateStoreReviewRequested = "rate_store_review_requested"
        
        case rateLowCaptured = "rate_low_captured"

        
        case pushPromptShown = "push_prompt_shown"
        case pushPromptAccepted = "push_prompt_accepted"
        case pushPromptDeclined = "push_prompt_declined"

        
        case iconBannerShown = "icon_banner_shown"
        case iconSwipeCompleted = "icon_swipe_completed"
        case iconBannerExpired = "icon_banner_expired"

        
        case fortuneWheelShown = "fortune_wheel_shown"
        case fortuneWheelSpun = "fortune_wheel_spun"
        case fortuneWheelCtaTapped = "fortune_wheel_cta_tapped"
        case fortuneWheelClosed = "fortune_wheel_closed"

        
        case nativeAdShown = "native_ad_shown"
        case nativeAdReported = "native_ad_reported"
        case nativeAdTargetingViewed = "native_ad_targeting_viewed"

        
        
        
        
        
        
        
        
        case deepLinkOpened = "deep_link_opened"

        
        
        
        
        
        case pushTapped = "push_tapped"
    }
}



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
