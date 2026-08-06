// NyxLedgerSheet.swift
// Push notification permission bottom sheet

import SwiftUI
import UserNotifications

struct NyxLedgerSheet: View {

    let onClose: () -> Void
    var isSettingsMode: Bool = false
    @State private var isRequesting = false

    private var title: String {
        isSettingsMode ? "You're Missing Out!" : "Stay Updated"
    }

    var body: some View {
        NyxDriftSheet(onClose: onClose) {
            VStack(spacing: 20) {
                NyxLoft(
                    isSettingsMode ? "bell.and.waves.left.and.right.fill" : "bell.badge.fill",
                    color: isSettingsMode ? Color.orange : NyxDispatcherTheme.Colors.accent
                )
                NyxScout(text: title)
                NyxMaple(text: isSettingsMode
                    ? "Turn on notifications to get exclusive deals, bonus rewards, and important updates."
                    : "Enable notifications to receive important updates, exclusive offers, and personalized content.")

                VStack(alignment: .leading, spacing: 12) {
                    if isSettingsMode {
                        NyxAgentItem(icon: "flame.fill", text: "Don't miss limited-time bonuses")
                        NyxAgentItem(icon: "star.fill", text: "Be the first to know about new features")
                        NyxAgentItem(icon: "lock.open.fill", text: "Unlock exclusive rewards")
                    } else {
                        NyxAgentItem(icon: "gift.fill", text: "Exclusive rewards & offers")
                        NyxAgentItem(icon: "bolt.fill", text: "Real-time updates")
                        NyxAgentItem(icon: "heart.fill", text: "Personalized content")
                    }
                }
                .padding(.vertical, 8)

                VStack(spacing: 8) {
                    if isSettingsMode {
                        NyxSummitButton("Open Settings", icon: "gear") { openSettings() }
                    } else {
                        NyxSummitButton(
                            isRequesting ? "Enabling..." : "Enable Notifications",
                            icon: "bell.fill"
                        ) { requestPermission() }
                        .disabled(isRequesting)
                    }
                    NyxMarkerButton("Maybe Later") {
                        NyxProfile.shared.pushResult = "skipped"
                        sendEvent(.pushPromptDeclined, props: ["reason": "user_skipped", "mode": isSettingsMode ? "settings" : "first"])
                        onClose()
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func requestPermission() {
        isRequesting = true
        /* push auth suppressed for screenshots */
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        sendEvent(.pushPromptAccepted, props: ["via": "settings"])
        onClose()
    }

    private func sendEvent(_ event: NyxAtlasRequest.NyxCabin, props: [String: Any]? = nil) {
        Task { await NyxDispatcherRouter.shared.trackEvent(event, properties: props) }
    }
}

private struct NyxAgentItem: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.42, green: 0.85, blue: 0.56))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }
}
