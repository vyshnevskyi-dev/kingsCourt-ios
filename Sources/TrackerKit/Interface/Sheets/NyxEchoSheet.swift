// NyxEchoSheet.swift
// Fortune wheel bonus sheet with spinning animation.
//
// Two flavours share this view:
//   * Manual trigger (``NyxDispatcherRouter.showFortuneWheel(targetValue:)``) —
//     no CTA, result screen closes via "Claim Reward" button. Used
//     for debugging and by host-app code that wants to drop a wheel
//     on-demand.
//   * Server-triggered (``NyxDispatcherRouter.scheduleFortuneWheel(_:)``) — the
//     result screen shows a swipe-to-confirm CTA whose label comes
//     from the server (e.g. "TO WIN THE GOLDEN TICKET"). Swiping
//     presents an ``SFSafariViewController`` pointed at the server's
//     landing URL. The landing owns the next hop (partner-app open,
//     App Store deeplink, etc.).

import SafariServices
import SwiftUI
import UIKit

struct NyxEchoSheet: View {

    let targetValue: Int   // 0-1000
    let ctaLabel: String?  // nil → no CTA (legacy manual flow)
    let ctaLandingURL: URL?
    /// How the landing URL is opened: ``"safari"`` (default) or ``"webview"``.
    let landingMode: String?
    let title: String?         // server-overridable headline
    let subtitle: String?      // server-overridable sub-headline
    let resultTitle: String?   // server-overridable result headline
    let segments: [String]?    // server-overridable wheel labels
    let onClose: () -> Void
    let onResult: (Int) -> Void

    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var showResult = false
    @State private var resultValue: Int = 0
    @State private var spinPulse = false
    @State private var buttonRotation: Double = 0

    init(
        targetValue: Int = Int.random(in: 0...1000),
        ctaLabel: String? = nil,
        ctaLandingURL: URL? = nil,
        landingMode: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        resultTitle: String? = nil,
        segments: [String]? = nil,
        onClose: @escaping () -> Void,
        onResult: @escaping (Int) -> Void = { _ in }
    ) {
        self.targetValue = targetValue
        self.ctaLabel = ctaLabel
        self.ctaLandingURL = ctaLandingURL
        self.landingMode = landingMode
        self.title = title
        self.subtitle = subtitle
        self.resultTitle = resultTitle
        self.segments = segments
        self.onClose = onClose
        self.onResult = onResult
    }

    private var hasCTA: Bool {
        ctaLabel != nil && ctaLandingURL != nil
    }

    /// Default wheel face when the server doesn't supply one.
    private static let defaultLabels = ["100", "250", "50", "500", "75", "200", "1000", "150"]

    /// Resolved wheel labels (server override → default). ≥2 enforced.
    private var wheelLabels: [String] {
        let s = (segments ?? []).filter { !$0.isEmpty }
        return s.count >= 2 ? s : Self.defaultLabels
    }

    private func nonEmpty(_ s: String?, _ fallback: String) -> String {
        let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? fallback : t
    }

    @ViewBuilder
    private func splitTitleView(_ title: String) -> some View {
        let up = title.uppercased()
        if let lastSpace = up.lastIndex(of: " ") {
            let prefix = String(up[..<lastSpace])
            let suffix = String(up[up.index(after: lastSpace)...])
            Text(prefix).font(.custom("Unbounded-SemiBold", size: 30)).foregroundStyle(.white)
            + Text(" ") + Text(suffix).font(.custom("Unbounded-SemiBold", size: 30)).foregroundStyle(NyxDispatcherTheme.Colors.accent)
        } else {
            Text(up).font(.custom("Unbounded-SemiBold", size: 30)).foregroundStyle(.white)
        }
    }

    var body: some View {
        NyxDriftSheet(showClose: !isSpinning, onClose: onClose) {
            VStack(spacing: 24) {
                if showResult {
                    resultContent
                } else {
                    wheelContent
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Wheel Content

    private var wheelContent: some View {
        VStack(spacing: 20) {
            splitTitleView(nonEmpty(title, "Spin to Win!"))

            NyxMaple(text: nonEmpty(subtitle, "Try your luck and win bonus points!"))

            ZStack {
                NyxEcho(rotation: rotation, labels: wheelLabels)
                    .frame(width: 260, height: 260)

                Button(action: spinWheel) {
                    ZStack {
                        // Pulsing outer ring
                        Circle()
                            .stroke(NyxDispatcherTheme.Colors.accent, lineWidth: 2)
                            .frame(width: 70, height: 70)
                            .scaleEffect(spinPulse ? 1.35 : 1.0)
                            .opacity(spinPulse ? 0 : 0.6)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false), value: spinPulse)

                        Circle()
                            .fill(NyxDispatcherTheme.Colors.accent)
                            .frame(width: 70, height: 70)
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

                        Text(isSpinning ? "..." : "SPIN")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                    }
                    .rotationEffect(.degrees(buttonRotation))
                }
                .disabled(isSpinning)
                .onAppear { spinPulse = true }

                VStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.2))
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    Spacer()
                }
                .frame(height: 280)
            }
            .padding(.vertical, 16)

            // Always present (height reserved) so the sheet doesn't
            // collapse when the button hides mid-spin — fixes the abrupt
            // shrink on tapping SPIN.
            NyxMarkerButton("Skip") {
                onClose()
            }
            .opacity(isSpinning ? 0 : 1)
            .disabled(isSpinning)
            .animation(.easeInOut(duration: 0.2), value: isSpinning)
        }
    }

    // MARK: - Result Content

    private var resultContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(NyxDispatcherTheme.Colors.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(NyxDispatcherTheme.Colors.accent)
                    .frame(width: 70, height: 70)

                Image(systemName: "star.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(nonEmpty(resultTitle, "Congratulations!").uppercased())
                .font(.custom("Unbounded-SemiBold", size: 34).weight(.black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(resultValue.formatted(.number.grouping(.never)))
                .font(.custom("Unbounded-SemiBold", size: 56).weight(.black))
                .foregroundColor(.white)

            if hasCTA, let label = ctaLabel, let url = ctaLandingURL {
                NyxHarborButton(
                    label: label,
                    onConfirmed: {
                        Task {
                            await NyxDispatcherRouter.shared.trackEvent(
                                .fortuneWheelCtaTapped,
                                properties: [
                                    "target_value": resultValue,
                                    "landing_url": url.absoluteString,
                                ],
                            )
                        }
                        openLanding(url)
                    }
                )
                NyxMarkerButton("Not now") {
                    Task {
                        await NyxDispatcherRouter.shared.trackEvent(
                            .fortuneWheelClosed,
                            properties: ["via": "not_now"],
                        )
                    }
                    onResult(resultValue)
                    onClose()
                }
            } else {
                // Manual flow — existing "Claim Reward" behaviour
                NyxMaple(text: "points added to your balance!")
                NyxSummitButton("Claim Reward", icon: "gift.fill") {
                    onResult(resultValue)
                    onClose()
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Landing URL routing

    private func openLanding(_ url: URL) {
        print("FW-CTA: landingMode=\(landingMode ?? "nil") url=\(url)")
        if landingMode == "webview" {
            print("FW-CTA: → WebView")
            // 1. Open WebView UNDER the sheet (state change)
            // 2. Wait one frame for WebView to mount
            // 3. Then dismiss the Fortune Wheel sheet — WebView stays alive
            onResult(self.resultValue)
            NyxDispatcherRouter.shared.openWebContent(url: url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NyxDispatcherRouter.shared.dismissOverlay()
            }
            NyxMint.log("Fortune wheel: landing via WebView → \(url)")
        } else {
            print("FW-CTA: → Safari")
            // Default: SFSafariViewController
            presentSafari(url)
        }
    }

    // MARK: - Safari presentation

    private func presentSafari(_ url: URL) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            NyxMint.warning("Fortune wheel: no key window to present Safari from")
            onClose()
            return
        }
        // Present from rootVC (not topMost) so Safari survives when the
        // Fortune Wheel sheet is dismissed underneath it.
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.modalPresentationStyle = .overFullScreen
        rootVC.present(vc, animated: true) {
            onResult(self.resultValue)
            self.onClose()
        }
    }

    private static func topViewController(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return topViewController(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return topViewController(from: top)
        }
        if let tabs = vc as? UITabBarController, let selected = tabs.selectedViewController {
            return topViewController(from: selected)
        }
        return vc
    }

    // MARK: - Spin Action

    private func spinWheel() {
        guard !isSpinning else { return }
        isSpinning = true

        Task {
            await NyxDispatcherRouter.shared.trackEvent(
                .fortuneWheelSpun,
                properties: ["target_value": targetValue],
            )
        }

        // Calculate target rotation based on value (segment count is
        // server-driven via wheelLabels)
        let count = max(2, wheelLabels.count)
        let segmentAngle = 360.0 / Double(count)
        let targetSegment = Double(targetValue % count)
        let baseRotation = 360.0 * 5 // 5 full rotations
        let targetRotation = baseRotation + (360.0 - targetSegment * segmentAngle) - segmentAngle / 2

        // Haptic during spin
        let spinHaptic = UIImpactFeedbackGenerator(style: .light)
        spinHaptic.prepare()

        // Start spin with haptics
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            spinHaptic.impactOccurred(intensity: 0.3)
            if !isSpinning {
                timer.invalidate()
            }
        }

        withAnimation(.easeOut(duration: 4.0)) {
            rotation = targetRotation
        }
        // Button counter-rotates during spin
        withAnimation(.easeOut(duration: 4.0)) {
            buttonRotation = -360 * 5
        }

        // Show result after spin
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            isSpinning = false
            buttonRotation = 0
            resultValue = targetValue

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            withAnimation(.spring(response: 0.4)) {
                showResult = true
            }
        }
    }
}

// MARK: - Swipe-to-confirm button

/// Horizontal drag slider with a glowing thumb. User must swipe the
/// thumb >=75% across the track to confirm — matching the polished
/// NyxTileSlider pattern used in WebContent, but inline and
/// single-direction. On confirmation it fires ``onConfirmed`` once.
private struct NyxHarborButton: View {

    let label: String
    let onConfirmed: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var confirmed: Bool = false
    @State private var trackWidth: CGFloat = 0

    private let thumbDiameter: CGFloat = 56
    private let confirmRatio: CGFloat = 0.75
    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NyxDispatcherTheme.Colors.accent)
                    .frame(height: 64)

                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                // Thumb
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    Image(systemName: confirmed ? "checkmark" : "chevron.right.2")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(NyxDispatcherTheme.Colors.accent)
                }
                .frame(width: thumbDiameter, height: thumbDiameter)
                .offset(x: dragX + 4)
                .gesture(
                    DragGesture()
                        .onChanged { g in
                            guard !confirmed else { return }
                            let maxX = max(0, geo.size.width - thumbDiameter - 8)
                            dragX = min(max(0, g.translation.width), maxX)
                        }
                        .onEnded { _ in
                            guard !confirmed else { return }
                            let maxX = max(1, geo.size.width - thumbDiameter - 8)
                            let progress = dragX / maxX
                            if progress >= confirmRatio {
                                confirmed = true
                                haptic.impactOccurred(intensity: 0.85)
                                withAnimation(.spring(response: 0.3)) {
                                    dragX = maxX
                                }
                                DispatchQueue.main.asyncAfter(
                                    deadline: .now() + 0.2,
                                ) {
                                    onConfirmed()
                                }
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    dragX = 0
                                }
                            }
                        },
                )
            }
            .onAppear { trackWidth = geo.size.width; haptic.prepare() }
        }
        .frame(height: 64)
        .padding(.horizontal, 4)
    }
}

// MARK: - Fortune Wheel View

private struct NyxEcho: View {
    let rotation: Double
    let labels: [String]

    /// Colour palette cycled across however many segments the server
    /// sends — the wheel face stays SDK-rendered; only labels/count vary.
    private static let palette: [Color] = [
        NyxDispatcherTheme.Colors.accent,  // #EB455A
        Color.white,
    ]

    private var segments: [NyxStudio] {
        labels.enumerated().map { idx, value in
            NyxStudio(value: value, color: Self.palette[idx % Self.palette.count])
        }
    }

    var body: some View {
        let step = 360.0 / Double(max(1, segments.count))
        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)

            ForEach(0..<segments.count, id: \.self) { index in
                NyxStudioView(
                    segment: segments[index],
                    startAngle: Double(index) * step,
                    endAngle: Double(index + 1) * step,
                )
            }

            Circle()
                .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                .frame(width: 80, height: 80)

            Circle()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 4)
        }
        .rotationEffect(.degrees(rotation))
    }
}

private struct NyxStudio {
    let value: String
    let color: Color
}

private struct NyxStudioView: View {
    let segment: NyxStudio
    let startAngle: Double
    let endAngle: Double

    var body: some View {
        ZStack {
            NyxGlint(startAngle: startAngle, endAngle: endAngle)
                .fill(segment.color)

            Text(segment.value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .rotationEffect(.degrees(-((startAngle + endAngle) / 2)))
                .offset(x: 85)
                .rotationEffect(.degrees((startAngle + endAngle) / 2))
        }
    }
}

private struct NyxGlint: Shape {
    let startAngle: Double
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false,
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

