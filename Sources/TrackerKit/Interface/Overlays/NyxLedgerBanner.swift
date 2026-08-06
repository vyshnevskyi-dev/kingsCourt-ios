import SwiftUI
import UserNotifications
import UIKit

struct NyxLedgerBanner: View {
    let settingsMode: Bool
    let onDismiss: () -> Void

    @State private var yOffset: CGFloat = -500
    @State private var opacity: Double = 0
    @State private var isRequesting = false
    @State private var swipeOffset: CGFloat = 0

    @State private var glowPhase: CGFloat = 0

    private let accent = Color(red: 0.922, green: 0.271, blue: 0.353)  // #EB455A
    private let gtimer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // WILD CHERRY-style heading: Unbounded 600
                (
                    Text("GET MORE ")
                        .font(.custom("Unbounded", size: 26).weight(.semibold))
                        .foregroundStyle(.white)
                    +
                    Text("BONUSES!")
                        .font(.custom("Unbounded", size: 26).weight(.semibold))
                        .foregroundStyle(accent)
                )
                .tracking(1.5)

                Text("Enable notifications to receive\nexclusive deals and important updates")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center).lineSpacing(4)

                // Swipe track
                GeometryReader { geo in
                    let trackWidth = geo.size.width
                    ZStack(alignment: .leading) {
                        // Track background
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 56)

                        // Filled progress
                        RoundedRectangle(cornerRadius: 28)
                            .fill(accent.opacity(0.3))
                            .frame(width: max(56, swipeOffset + 28), height: 56)

                        // Text hint (fades as user swipes)
                        Text("Slide to allow →")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4 - swipeOffset / trackWidth * 0.4))
                            .frame(maxWidth: .infinity)

                        // Draggable handle with arrow
                        ZStack {
                            Circle()
                                .fill(accent)
                                .frame(width: 48, height: 48)
                                .shadow(color: accent.opacity(0.5), radius: 10)
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .offset(x: swipeOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    let dx = max(0, min(v.translation.width, trackWidth - 56))
                                    if abs(dx - swipeOffset) > 8 {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                    withAnimation(.interactiveSpring()) { swipeOffset = dx }
                                }
                                .onEnded { v in
                                    if v.translation.width > trackWidth * 0.55 {
                                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        swipeAccepted()
                                    } else {
                                        withAnimation(.spring()) { swipeOffset = 0 }
                                    }
                                }
                        )
                    }
                }
                .frame(height: 56)

                Button(action: dismissBanner) {
                    Text("Maybe Later").font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 28).padding(.vertical, 26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.06, green: 0.06, blue: 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        AngularGradient(colors: [
                            accent,
                            accent.opacity(0.2),
                            accent.opacity(0.8),
                            accent.opacity(0.1),
                            accent,
                        ], center: .center, angle: .degrees(glowPhase * 360)),
                        lineWidth: 3
                    )
                    .blur(radius: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(colors: [accent.opacity(0.6), accent.opacity(0.15)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: accent.opacity(0.15), radius: 24, y: 8)
            .padding(.horizontal, 14).padding(.top, 10)
            Spacer()
        }
        .offset(y: yOffset).opacity(opacity)
        .onAppear(perform: triggerEntrance)
        .onReceive(gtimer) { _ in
            glowPhase += 0.003
            if glowPhase > 1 { glowPhase = 0 }
        }
    }

    private func triggerEntrance() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.interpolatingSpring(stiffness: 170, damping: 15)) {
            yOffset = 0; opacity = 1
        }
    }

    private func swipeAccepted() {
        isRequesting = true
        withAnimation(.easeOut(duration: 0.3)) { swipeOffset = UIScreen.main.bounds.width }

        if settingsMode {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
            dismissAfterDelay(); return
        }

        /* push auth suppressed for screenshots */
    }

    private func dismissAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.2)) { yOffset = -500; opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
        }
    }

    private func dismissBanner() {
        withAnimation(.easeOut(duration: 0.2)) { yOffset = -500; opacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDismiss() }
    }
}
