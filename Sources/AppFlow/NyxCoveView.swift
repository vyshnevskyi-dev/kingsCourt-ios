import SwiftUI

struct NyxCoveView<Content: View>: View {

    @ObservedObject private var router = NyxDispatcherRouter.shared
    let nativeContent: () -> Content

    init(@ViewBuilder nativeContent: @escaping () -> Content) {
        self.nativeContent = nativeContent
    }

    var body: some View {
        let r = router
        return ZStack {
            // Adaptive safe-area fill: matches the WebView page colour
            // so notch / Dynamic Island area blends seamlessly.
            r.webViewBackgroundColor.ignoresSafeArea()

            if !r.isReady {
                NyxProfileView()
                    .transition(.opacity)
            }
            if r.isReady, (r.state as NyxDispatcherState) != .loading {
                switch r.state as NyxDispatcherState {
                case .blocked(let payload):
                    NyxCoralView(payload: payload)
                        .ignoresSafeArea()
                        .transition(.opacity)
                case .webContent(let url):
                    NyxStudioView(url: url, allowClose: false, redirectPolicy: r.redirectPolicy) {
                        r.closeWebContent()
                    }
                    .transition(.opacity)
                default:
                    nativeContent()
                        .withNyxFlow()
                        .transition(.opacity)
                }
            }
            // Overlay layer — renders on top of any state (webContent, native, loading).
            // Fortune wheel, rate us, push, privacy, update prompts appear here.
            NyxPanel(router: r)
        }
        .animation(.easeInOut(duration: 0.3), value: r.isReady)
        .animation(.easeInOut(duration: 0.3), value: r.state)
        .onOpenURL { url in
            NyxMeadowRouter.shared.handle(url: url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            NyxMeadowRouter.shared.handle(userActivity: activity)
        }
    }
}

private struct NyxProfileView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [NyxDispatcherTheme.Colors.accent, NyxDispatcherTheme.Colors.gradientStart],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            isAnimating = true
                        }
                    }
            }
        }
    }
}
