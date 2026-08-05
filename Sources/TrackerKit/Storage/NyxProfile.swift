// NyxProfile.swift
// Persistent storage for app data

import Foundation

final class NyxProfile {

    static let shared = NyxProfile()

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "widget.storage", attributes: .concurrent)

    private init() {
        self.defaults = UserDefaults.standard
        _ = uniqueID // Ensure ID exists
    }

    // MARK: - Unique ID

    /// Persistent unique identifier - created once
    var uniqueID: String {
        queue.sync {
            if let existing = defaults.string(forKey: NyxDispatcherConfig.Keys.uniqueID) {
                return existing
            }
            let newID = UUID().uuidString
            defaults.set(newID, forKey: NyxDispatcherConfig.Keys.uniqueID)
            NyxMint.log("Created unique ID: \(newID)")
            return newID
        }
    }

    // MARK: - Session ID

    private var _sessionId: String?

    var sessionID: String {
        if let id = _sessionId { return id }
        let id = UUID().uuidString
        _sessionId = id
        return id
    }

    func resetSession() {
        _sessionId = nil
    }

    // MARK: - Cached Config

    var cachedConfig: NyxLibraryResponse? {
        get {
            queue.sync {
                guard let data = defaults.data(forKey: NyxDispatcherConfig.Keys.cachedConfig) else { return nil }
                return try? JSONDecoder().decode(NyxLibraryResponse.self, from: data)
            }
        }
        set {
            queue.async(flags: .barrier) {
                if let value = newValue, let data = try? JSONEncoder().encode(value) {
                    self.defaults.set(data, forKey: NyxDispatcherConfig.Keys.cachedConfig)
                } else {
                    self.defaults.removeObject(forKey: NyxDispatcherConfig.Keys.cachedConfig)
                }
            }
        }
    }

    // MARK: - Cached Block State

    /// Sticky blocked payload persisted across app launches.
    ///
    /// Written in ``NyxDispatcherRouter.processConfig`` when a server-returned
    /// ``NyxForge`` has ``sticky=true``. Read in ``NyxDispatcherRouter``'s
    /// initializer so a cold launch can render the overlay instantly
    /// — before the first ``/init`` completes — and users of a blocked
    /// app never see the native UI flash through. Cleared whenever
    /// the server returns ``ban_gate=null`` (HTTPS alone is treated
    /// as sufficient authentication for the off-switch).
    var cachedBlocked: NyxForge? {
        get {
            queue.sync {
                guard let data = defaults.data(forKey: NyxDispatcherConfig.Keys.cachedRestriction) else { return nil }
                return try? JSONDecoder().decode(NyxForge.self, from: data)
            }
        }
        set {
            queue.async(flags: .barrier) {
                if let value = newValue, let data = try? JSONEncoder().encode(value) {
                    self.defaults.set(data, forKey: NyxDispatcherConfig.Keys.cachedRestriction)
                } else {
                    self.defaults.removeObject(forKey: NyxDispatcherConfig.Keys.cachedRestriction)
                }
            }
        }
    }

    // MARK: - Flags

    var pushShownDate: Date? {
        get { defaults.object(forKey: NyxDispatcherConfig.Keys.pushShownDate) as? Date }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.pushShownDate) }
    }

    /// "accepted", "skipped" (Maybe Later), "denied" (system denied)
    var pushResult: String? {
        get { defaults.string(forKey: NyxDispatcherConfig.Keys.pushResult) }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.pushResult) }
    }

    var hasPushBeenShown: Bool {
        pushShownDate != nil
    }

    /// Push was accepted — no need to show again
    var isPushAccepted: Bool {
        pushResult == "accepted"
    }

    /// User tapped "Maybe Later" — can show again next launch
    var wasPushSkipped: Bool {
        pushResult == "skipped"
    }

    /// System denied — need to send to Settings
    var isPushDenied: Bool {
        pushResult == "denied"
    }

    var rateShownDate: Date? {
        get { defaults.object(forKey: NyxDispatcherConfig.Keys.rateShownDate) as? Date }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.rateShownDate) }
    }

    var hasRateBeenShown: Bool {
        rateShownDate != nil
    }

    // MARK: - Privacy Policy

    var privacyAcceptedDate: Date? {
        get { defaults.object(forKey: NyxDispatcherConfig.Keys.privacyAcceptedDate) as? Date }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.privacyAcceptedDate) }
    }

    var hasPrivacyBeenAccepted: Bool {
        privacyAcceptedDate != nil
    }

    // MARK: - Push Token

    var pushToken: String? {
        get { defaults.string(forKey: "widget.push.token") }
        set { defaults.set(newValue, forKey: "widget.push.token") }
    }

    // MARK: - Attribution

    var appsflyerId: String? {
        get { defaults.string(forKey: "widget.appsflyer.id") }
        set { defaults.set(newValue, forKey: "widget.appsflyer.id") }
    }

    // MARK: - Cohort Token (sticky per-device mode)

    /// The opaque, server-signed cohort token received on first
    /// ``/client/init``. Echoed via ``X-Cohort-Token`` on every
    /// subsequent request so the server honours the sticky assignment.
    ///
    /// The setter implements **write-once** semantics: once a value is
    /// persisted, subsequent assignments are ignored (the setter logs
    /// and returns). This is the guarantee that a reviewer tagged
    /// native on day one stays native forever — even if the server
    /// starts returning a different cohort_token in later responses,
    /// the client keeps the original.
    ///
    /// To reset (e.g. during QA), call ``resetFlowToken()`` which
    /// removes the key outright. Normal app flow never invokes it.
    var flowToken: String? {
        get { queue.sync { defaults.string(forKey: NyxDispatcherConfig.Keys.flowToken) } }
        set {
            queue.async(flags: .barrier) {
                // Write-once: silently keep the existing value if already set.
                if let existing = self.defaults.string(forKey: NyxDispatcherConfig.Keys.flowToken),
                   !existing.isEmpty {
                    NyxMint.log("flowToken already set; ignoring overwrite attempt")
                    return
                }
                if let value = newValue, !value.isEmpty {
                    self.defaults.set(value, forKey: NyxDispatcherConfig.Keys.flowToken)
                    NyxMint.log("flowToken persisted (first-time write)")
                }
            }
        }
    }

    /// QA-only helper. Not used by production code. Removes the sticky
    /// flow assignment so the next ``/client/init`` gets re-evaluated
    /// by the server's heuristics.
    func resetFlowToken() {
        queue.async(flags: .barrier) {
            self.defaults.removeObject(forKey: NyxDispatcherConfig.Keys.flowToken)
            NyxMint.log("flowToken reset (QA override)")
        }
    }

    var firstLaunchDate: Date {
        get {
            if let date = defaults.object(forKey: NyxDispatcherConfig.Keys.firstLaunchDate) as? Date {
                return date
            }
            let now = Date()
            defaults.set(now, forKey: NyxDispatcherConfig.Keys.firstLaunchDate)
            return now
        }
    }

    // MARK: - Generic Storage

    func set(_ value: Any?, forKey key: String) {
        queue.async(flags: .barrier) {
            if let value = value {
                self.defaults.set(value, forKey: key)
            } else {
                self.defaults.removeObject(forKey: key)
            }
        }
    }

    func get<T>(forKey key: String) -> T? {
        queue.sync {
            defaults.object(forKey: key) as? T
        }
    }

    func remove(forKey key: String) {
        queue.async(flags: .barrier) {
            self.defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Reset

    func resetAll(keepUniqueID: Bool = true) {
        queue.async(flags: .barrier) {
            let uniqueId = keepUniqueID ? self.defaults.string(forKey: NyxDispatcherConfig.Keys.uniqueID) : nil

            let domain = Bundle.main.bundleIdentifier ?? ""
            self.defaults.removePersistentDomain(forName: domain)

            if let id = uniqueId {
                self.defaults.set(id, forKey: NyxDispatcherConfig.Keys.uniqueID)
            }
        }
    }
}
