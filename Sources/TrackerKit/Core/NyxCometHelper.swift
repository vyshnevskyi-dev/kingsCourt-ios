





import UIKit
import AdServices

#if APPFLOW_ATT_ENABLED
import AdSupport
import AppTrackingTransparency
#endif

final class NyxCometHelper {

    nonisolated(unsafe) static let shared = NyxCometHelper()
    private init() {}

    

    
    
    func registerASAAttribution() {
        if #available(iOS 14.3, *) {
            do {
                let token = try AAAttribution.attributionToken()
                NyxMint.log("ASA attribution token: \(token.prefix(40))...")
            } catch {
                NyxMint.log("ASA attribution not available: \(error.localizedDescription)")
            }
        } else {
            NyxMint.log("ASA attribution requires iOS 14.3+")
        }
    }

    

    var bundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    

    var language: String {
        if #available(iOS 16, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }

    var timezone: String {
        TimeZone.current.identifier
    }

    var region: String {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier ?? "US"
        } else {
            return Locale.current.regionCode ?? "US"
        }
    }

    var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { id, element in
            guard let value = element.value as? Int8, value != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(value)))
        }
    }

    var osVersion: String {
        UIDevice.current.systemVersion
    }

    var screenScale: Double {
        Double(UIScreen.main.scale)
    }

    
    
    
    var screenWidthPoints: Int {
        Int(UIScreen.main.bounds.size.width)
    }

    
    
    var screenHeightPoints: Int {
        Int(UIScreen.main.bounds.size.height)
    }

    

    var vendorID: String? {
        UIDevice.current.identifierForVendor?.uuidString
    }

    

    #if APPFLOW_ATT_ENABLED

    

    var trackingStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    var trackingStatusString: String {
        switch trackingStatus {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown"
        }
    }

    var advertisingID: String? {
        guard trackingStatus == .authorized else { return nil }
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        guard idfa != "00000000-0000-0000-0000-000000000000" else { return nil }
        return idfa
    }

    func requestTrackingPermission() async -> ATTrackingManager.AuthorizationStatus {
        guard trackingStatus == .notDetermined else {
            return trackingStatus
        }

        
        while await UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return await ATTrackingManager.requestTrackingAuthorization()
    }

    #else

    

    var trackingStatusString: String {
        "unavailable"
    }

    var advertisingID: String? {
        nil
    }

    func requestTrackingPermission() async {
        
    }

    #endif
}
