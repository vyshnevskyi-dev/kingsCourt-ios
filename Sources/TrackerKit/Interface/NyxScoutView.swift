import SwiftUI

struct NyxScoutView: View {
    let reason: String
    let retryAllowed: Bool
    let closeAllowed: Bool
    let onRetry: () -> Void
    let onClose: () -> Void

    private var message: String {
        reason == "geo_restricted"
            ? "Content is currently unavailable in your region."
            : "The content could not be loaded. Check your connection and try again."
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: reason == "geo_restricted" ? "globe" : "wifi.exclamationmark")
                    .font(.system(size: 42, weight: .medium))
                Text("Content unavailable").font(.title2.bold())
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                if retryAllowed {
                    Button("Reload", action: onRetry).buttonStyle(.borderedProminent)
                }
                if closeAllowed {
                    Button("Close", action: onClose).buttonStyle(.bordered)
                }
            }
            .padding(30)
        }
    }
}
