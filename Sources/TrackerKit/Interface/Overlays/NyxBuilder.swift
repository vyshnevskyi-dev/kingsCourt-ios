


import SwiftUI

struct NyxBuilder: View {

    @ObservedObject var router: NyxDispatcherRouter

    init(router: NyxDispatcherRouter = NyxDispatcherRouter.shared) {
        self.router = router
    }

    var body: some View {
        ZStack {
            if let type = router.overlay {
                
                if case .iconChange(let name) = type {
                    NyxPointerBanner(
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
                    
                    sheetContent(for: type)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if case .nativeAd = type {
                    
                    sheetContent(for: type)
                        .transition(.opacity)
                } else {
                    
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            if case .forceUpdate = type { return }
                            router.dismissOverlay()
                        }

                    
                    sheetContent(for: type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: router.state)
    }

    @ViewBuilder
    private func sheetContent(for type: NyxNexusType) -> some View {
        switch type {
        case .pushPermission(let settingsMode):
            
            NyxOnyxBanner(settingsMode: settingsMode, onDismiss: { router.dismissOverlay() })

        case .rateApp:
            NyxSummitSheet {
                router.dismissOverlay()
            }

        case .forceUpdate:
            NyxTempoSheet(
                storeURL: router.currentConfig?.storeURL,
                isForced: router.currentConfig?.shouldForceUpdate ?? true
            ) {
                router.dismissOverlay()
            }

        case .fortuneWheel(let targetValue, let ctaLabel, let ctaLandingURL,
                           let landingMode, let title, let subtitle, let resultTitle,
                           let segments):
            NyxBeaconSheet(
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

        case .nativeAd(let mediaURL, let mediaType, let adID, let advertiserName,
                       let targetingDisclosure, let autoCloseSec):
            NyxPanelSheet(
                mediaURL: mediaURL,
                mediaType: mediaType,
                adID: adID,
                advertiserName: advertiserName,
                targetingDisclosure: targetingDisclosure,
                autoCloseSec: autoCloseSec,
                onReport: { reason in
                    router.reportNativeAd(adID: adID, reason: reason, advertiser: advertiserName)
                },
                onClose: { router.dismissOverlay() }
            )

        case .privacyPolicy(let url):
            NyxRunnerSheet(
                privacyURL: url ?? NyxDispatcherConfig.privacyURL,
                termsURL: NyxDispatcherConfig.termsURL,
                onAgree: {
                    
                    NyxGallery.shared.privacyAcceptedDate = Date()
                    NyxMint.log("Privacy policy accepted")
                },
                onClose: {
                    router.dismissOverlay()
                }
            )

        case .iconChange:
            
            EmptyView()
        }
    }
}



struct NyxTempoSheet: View {

    let storeURL: URL?
    let isForced: Bool
    let onClose: () -> Void

    @State private var isAnimating = false

    var body: some View {
        NyxDriftSheet(showClose: !isForced, onClose: isForced ? {} : onClose) {
            VStack(spacing: 20) {
                
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

                NyxStage(text: "Update Available")

                NyxHarbor(text: isForced
                    ? "A new version is required. Please update to continue."
                    : "A new version is available with exciting features!"
                )

                VStack(spacing: 8) {
                    NyxPortalButton("Update Now", icon: "arrow.down.circle.fill") {
                        if let url = storeURL {
                            UIApplication.shared.open(url)
                        }
                    }

                    if !isForced {
                        NyxRangerButton("Remind Me Later") {
                            onClose()
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}



struct NyxPlannerOverlay: View {

    @ObservedObject var router: NyxDispatcherRouter

    init(router: NyxDispatcherRouter = NyxDispatcherRouter.shared) {
        self.router = router
    }

    var body: some View {
        ZStack {
            
            NyxBuilder(router: router)

            
            if case .webContent(let url) = router.state {
                NyxVaultView(
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



struct NyxStreamModifier: ViewModifier {

    @ObservedObject private var router = NyxDispatcherRouter.shared
    @State private var showSettings = false

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            NyxPlannerOverlay(router: router)

            
            
            
            
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

    
    
    private var showSettingsGear: Bool {
        guard NyxDispatcherConfig.privacyInSettingsEnabled, NyxDispatcherConfig.privacyURL != nil else {
            return false
        }
        if case .nativeContent = router.state { return true }
        return false
    }
}

extension View {
    
    func withNyxFlow() -> some View {
        modifier(NyxStreamModifier())
    }
}


