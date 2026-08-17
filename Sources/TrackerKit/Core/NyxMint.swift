// NyxMint.swift
// Simple logging utility

import Foundation
import os.log

enum NyxMint {

    private static let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "App")

    nonisolated(unsafe) static var isEnabled = NyxDispatcherConfig.isLoggingEnabled

    // MARK: - Logging

    static func log(_ message: String, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        #if DEBUG
        print("[\(fileName):\(line)] \(message)")
        #endif
        os_log("%{public}@", log: osLog, type: .debug, message)
    }

    static func error(_ message: String, _ error: Error? = nil) {
        guard isEnabled else { return }
        var msg = "ERROR: \(message)"
        if let error = error {
            msg += " | \(error.localizedDescription)"
        }
        #if DEBUG
        print(msg)
        #endif
        os_log("%{public}@", log: osLog, type: .error, msg)
    }

    static func warning(_ message: String) {
        guard isEnabled else { return }
        #if DEBUG
        print("WARNING: \(message)")
        #endif
        os_log("WARNING: %{public}@", log: osLog, type: .default, message)
    }

    // MARK: - Network Logging

    static func logRequest(_ url: String, method: String, body: Data?) {
        guard isEnabled else { return }
        var msg = ">> \(method) \(url)"
        if let body = body, let str = String(data: body, encoding: .utf8) {
            msg += "\n   Body: \(str)"
        }
        log(msg)
    }

    static func logResponse(_ url: String, status: Int, data: Data?) {
        guard isEnabled else { return }
        var msg = "<< \(status) \(url)"
        if let data = data, let str = String(data: data, encoding: .utf8) {
            msg += "\n   Response: \(str)"
        }
        log(msg)
    }
}
