// NyxRoster.swift
// Main overlay container that displays the appropriate sheet based on router state

import SwiftUI

struct NyxRoster: View {

    @ObservedObject var router: NyxDispatcherRouter

    init(router: NyxDispatcherRouter = NyxDispatcherRouter.shared) {
        self.router = router
    }

    var body: some View {
        ZStack {
            if let type = router.overlay {
                // Icon change banner shows from top without dimming
                if case .iconChange(let name) = type {
                    NyxCobaltBanner(
                        iconName: name,
                        duration: 5,
                        onSwipeCompleted: {
                            router.handleIconSwipeCompleted()
                        },
                        onExpired: {
                            router.handleIconBannerExpired()
                        },
                        onDismiss: {
                            router.dismissOverlay()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                } else if case .pushPermission = type {
                    // Push — top banner, slides from top
                    sheetContent(for: type)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    // Dimmed background for bottom sheets
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            if case .forceUpdate = type { return }
                            router.dismissOverlay()
                        }

                    // Sheet content
                    sheetContent(for: type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: router.state)
    }

    @ViewBuilder
    private func sheetContent(for type: NyxPanelType) -> some View {
        switch type {
        case .pushPermission(let settingsMode):
            // Compact top banner for push — slides from top
            NyxLedgerBanner(settingsMode: settingsMode, onDismiss: { router.dismissOverlay() })

        case .rateApp:
            NyxOnyxSheet {
                router.dismissOverlay()
            }

        case .forceUpdate:
            NyxStageSheet(
                storeURL: router.currentConfig?.storeURL,
                isForced: router.currentConfig?.shouldForceUpdate ?? true
            ) {
                router.dismissOverlay()
            }

        case .fortuneWheel(let targetValue, let ctaLabel, let ctaLandingURL,
                           let landingMode, let title, let subtitle, let resultTitle,
                           let segments):
            NyxEchoSheet(
                targetValue: targetValue,
                ctaLabel: ctaLabel,
                ctaLandingURL: ctaLandingURL,
                landingMode: landingMode,
                title: title,
                subtitle: subtitle,
                resultTitle: resultTitle,
                segments: segments,
                onClose: {
                    router.dismissOverlay()
                }
            )

        case .privacyPolicy(let url):
            NyxCompassSheet(
                privacyURL: url,
                onAgree: {
                    // Save acceptance date
                    NyxProfile.shared.privacyAcceptedDate = Date()
                    NyxMint.log("Privacy policy accepted")
                },
                onClose: {
                    router.dismissOverlay()
                }
            )

        case .iconChange:
            // Handled directly in body (top banner, not bottom sheet)
            EmptyView()
        }
    }
}

// MARK: - Update Sheet

struct NyxStageSheet: View {

    let storeURL: URL?
    let isForced: Bool
    let onClose: () -> Void

    @State private var isAnimating = false

    var body: some View {
        NyxDriftSheet(showClose: !isForced, onClose: isForced ? {} : onClose) {
            VStack(spacing: 20) {
                // Animated icon
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.58, green: 0.28, blue: 0.98), Color(red: 0.42, green: 0.85, blue: 0.56)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))

                    Circle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                        .frame(width: 60, height: 60)

                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.58, green: 0.28, blue: 0.98), Color(red: 0.42, green: 0.85, blue: 0.56)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .onAppear {
                    withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }

                NyxScout(text: "Update Available")

                NyxMaple(text: isForced
                    ? "A new version is required. Please update to continue."
                    : "A new version is available with exciting features!"
                )

                VStack(spacing: 8) {
                    NyxSummitButton("Update Now", icon: "arrow.down.circle.fill") {
                        if let url = storeURL {
                            UIApplication.shared.open(url)
                        }
                    }

                    if !isForced {
                        NyxMarkerButton("Remind Me Later") {
                            onClose()
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Full Screen Overlay

struct NyxBeaconOverlay: View {

    @ObservedObject var router: NyxDispatcherRouter

    init(router: NyxDispatcherRouter = NyxDispatcherRouter.shared) {
        self.router = router
    }

    var body: some View {
        ZStack {
            // Sheet overlays
            NyxRoster(router: router)

            // WebView overlay
            if case .webContent(let url) = router.state {
                NyxAspenView(
                    url: url,
                    allowClose: false
                ) {
                    router.closeWebContent()
                }
                .ignoresSafeArea()
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: router.state)
    }
}

// MARK: - View Modifier

struct NyxStreamModifier: ViewModifier {

    @ObservedObject private var router = NyxDispatcherRouter.shared
    @State private var showSettings = false

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            NyxBeaconOverlay(router: router)

            // #1: discreet settings gear over native content. Opt-in
            // (privacy_in_settings) + only when a real privacy URL is
            // baked AND native content is showing — never over the
            // WebView / blocked screen / a dimmed overlay sheet.
            if showSettingsGear {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(9)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.top, 6)
                .padding(.trailing, 12)
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            NyxBrokerView()
        }
    }

    /// Show the gear only on native content, when the feature is on and a
    /// real (non-placeholder) privacy URL is present.
    private var showSettingsGear: Bool {
        guard NyxDispatcherConfig.privacyInSettingsEnabled, NyxDispatcherConfig.privacyURL != nil else {
            return false
        }
        if case .nativeContent = router.state { return true }
        return false
    }
}

extension View {
    /// Adds app flow overlay system to this view
    func withNyxFlow() -> some View {
        modifier(NyxStreamModifier())
    }
}

// MARK: - Preview

