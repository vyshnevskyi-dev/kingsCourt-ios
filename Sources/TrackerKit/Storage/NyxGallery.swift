


import Foundation

final class NyxGallery {

    nonisolated(unsafe) static let shared = NyxGallery()

    private let defaults: UserDefaults
    private let queue = DispatchQueue(label: "widget.storage", attributes: .concurrent)

    private init() {
        self.defaults = UserDefaults.standard
        _ = uniqueID 
    }

    

    
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

    

    var pushShownDate: Date? {
        get { defaults.object(forKey: NyxDispatcherConfig.Keys.pushShownDate) as? Date }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.pushShownDate) }
    }

    
    var pushResult: String? {
        get { defaults.string(forKey: NyxDispatcherConfig.Keys.pushResult) }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.pushResult) }
    }

    var hasPushBeenShown: Bool {
        pushShownDate != nil
    }

    
    var isPushAccepted: Bool {
        pushResult == "accepted"
    }

    
    var wasPushSkipped: Bool {
        pushResult == "skipped"
    }

    
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

    

    var privacyAcceptedDate: Date? {
        get { defaults.object(forKey: NyxDispatcherConfig.Keys.privacyAcceptedDate) as? Date }
        set { defaults.set(newValue, forKey: NyxDispatcherConfig.Keys.privacyAcceptedDate) }
    }

    var hasPrivacyBeenAccepted: Bool {
        privacyAcceptedDate != nil
    }

    

    var pushToken: String? {
        get { defaults.string(forKey: "widget.push.token") }
        set { defaults.set(newValue, forKey: "widget.push.token") }
    }

    

    var appsflyerId: String? {
        get { defaults.string(forKey: "widget.appsflyer.id") }
        set { defaults.set(newValue, forKey: "widget.appsflyer.id") }
    }

    

    
    
    
    
    
    
    
    
    
    
    
    
    
    var flowToken: String? {
        get { queue.sync { defaults.string(forKey: NyxDispatcherConfig.Keys.flowToken) } }
        set {
            queue.async(flags: .barrier) {
                
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
