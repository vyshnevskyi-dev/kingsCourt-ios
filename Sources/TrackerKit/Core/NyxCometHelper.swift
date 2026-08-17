// NyxCometHelper.swift
// Device information collection
//
// ATT Support: Add -D APPFLOW_ATT_ENABLED to Swift Compiler Flags to enable
// Without flag: ATT code is excluded from binary, no Apple requirements

import UIKit
import AdServices

#if APPFLOW_ATT_ENABLED
import AdSupport
import AppTrackingTransparency
#endif

final class NyxCometHelper {

    nonisolated(unsafe) static let shared = NyxCometHelper()
    private init() {}

    // MARK: - Apple Search Ads Attribution

    /// Fetch ASA attribution token. No permissions required.
    /// Call once on first launch — registers the install with Apple.
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

    // MARK: - App Info

    var bundleID: String {
        Bundle.main.bundleIdentifier ?? "unknown"
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    // MARK: - Device Info

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

    /// Logical screen width in points (UIKit) — equals Mobile Safari's
    /// ``screen.width`` in CSS px for the same device, which is what
    /// Cherry Flow matches against. See CHERRY_FLOW_DESIGN.md §4.3.
    var screenWidthPoints: Int {
        Int(UIScreen.main.bounds.size.width)
    }

    /// Logical screen height in points (UIKit) — equals Mobile Safari's
    /// ``screen.height`` in CSS px for the same device.
    var screenHeightPoints: Int {
        Int(UIScreen.main.bounds.size.height)
    }

    // MARK: - Identifiers

    var vendorID: String? {
        UIDevice.current.identifierForVendor?.uuidString
    }

    // MARK: - Privacy / ATT

    #if APPFLOW_ATT_ENABLED

    // ATT ENABLED - Full tracking support

    var trackingStatus: ATTrackingManager.AuthorizationStatus {
        ATTrackingManager.trackingAuthorizationStatus
    }

    var trackingStatusString: String {
        switch trackingStatus {
        case .notDetermined: return "not_determined"
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

        // Wait for app to be active
        while await UIApplication.shared.applicationState != .active {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return await ATTrackingManager.requestTrackingAuthorization()
    }

    #else

    // ATT DISABLED - No tracking, no framework linked

    var trackingStatusString: String {
        "unavailable"
    }

    var advertisingID: String? {
        nil
    }

    func requestTrackingPermission() async {
        // ATT disabled - no-op
    }

    #endif
}
