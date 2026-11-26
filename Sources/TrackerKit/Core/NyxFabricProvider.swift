import Foundation
import WebKit






@MainActor
enum NyxFabricProvider {
    private static let cacheKey = "app.webview.user-agent"
    private static var memoryCache: String?

    static func resolve(timeout: TimeInterval = 2.0) async -> String? {
        if let memoryCache, !memoryCache.isEmpty { return memoryCache }
        if let cached = UserDefaults.standard.string(forKey: cacheKey),
           !cached.isEmpty {
            memoryCache = cached
            return cached
        }

        let value = await withCheckedContinuation { continuation in
            NyxPlayer(timeout: timeout, continuation: continuation).start()
        }
        guard let value, !value.isEmpty else { return nil }
        memoryCache = value
        UserDefaults.standard.set(value, forKey: cacheKey)
        return value
    }
}

@MainActor
private final class NyxPlayer {
    private let webView = WKWebView(frame: .zero)
    private let timeout: TimeInterval
    private var continuation: CheckedContinuation<String?, Never>?

    init(
        timeout: TimeInterval,
        continuation: CheckedContinuation<String?, Never>
    ) {
        self.timeout = timeout
        self.continuation = continuation
    }

    func start() {
        webView.evaluateJavaScript("navigator.userAgent") { [self] result, _ in
            finish(result as? String)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [self] in
            finish(nil)
        }
    }

    private func finish(_ value: String?) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: value)
    }
}
