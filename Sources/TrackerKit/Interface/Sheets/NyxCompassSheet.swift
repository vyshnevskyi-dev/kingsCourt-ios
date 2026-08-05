// NyxCompassSheet.swift
// Privacy policy agreement with swipe-to-agree slider

import SwiftUI

struct NyxCompassSheet: View {

    let privacyURL: URL?
    let onAgree: () -> Void
    let onClose: () -> Void

    @State private var showWebView = false

    var body: some View {
        if showWebView, let url = privacyURL {
            NyxAspenView(url: url, allowClose: true) {
                showWebView = false
            }
            .transition(.move(edge: .trailing))
        } else {
            NyxDriftSheet(onClose: onClose) {
                VStack(spacing: 20) {
                    NyxLoft("doc.text.fill", color: NyxDispatcherTheme.Colors.accent)

                    NyxScout(text: "Terms & Privacy")

                    NyxMaple(text: "Please review and accept our Terms of Service and Privacy Policy to continue.")

                    // Privacy Policy link
                    if privacyURL != nil {
                        Button(action: {
                            if let url = privacyURL { UIApplication.shared.open(url) }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Open in Safari")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(NyxDispatcherTheme.Colors.accent)
                        }
                        .padding(.vertical, 8)
                    }

                    // Swipe to agree slider
                    NyxRangerSlider {
                        onAgree()
                        onClose()
                    }
                    .padding(.top, 8)

                    NyxMarkerButton("Decline") {
                        onClose()
                    }
                }
                .padding(.top, 8)
            }
            .transition(.move(edge: .bottom))
        }
    }
}

// MARK: - Swipe To Agree Slider

struct NyxRangerSlider: View {

    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isCompleted = false

    private let sliderWidth: CGFloat = 280
    private let thumbSize: CGFloat = 54
    private let trackHeight: CGFloat = 60

    var body: some View {
        ZStack(alignment: .leading) {
            // Track background
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .frame(width: sliderWidth, height: trackHeight)

            // Progress fill
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            NyxDispatcherTheme.Colors.accent.opacity(0.5),
                            NyxDispatcherTheme.Colors.accentLight.opacity(0.5),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: offset + thumbSize + 6, height: trackHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Hint text
            HStack {
                Spacer()
                Text("Swipe to agree")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(1 - Double(offset / maxOffset) * 2)
                Spacer()
            }
            .frame(width: sliderWidth)

            // Animated arrows
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .opacity(arrowOpacity(for: index))
                }
            }
            .offset(x: thumbSize + 16)

            // Thumb
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [NyxDispatcherTheme.Colors.accent, NyxDispatcherTheme.Colors.accentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: thumbSize, height: thumbSize - 6)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)

                Image(systemName: isCompleted ? "checkmark" : "arrow.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .offset(x: offset + 3)
            .gesture(dragGesture)
        }
        .frame(width: sliderWidth, height: trackHeight)
    }

    private var maxOffset: CGFloat {
        sliderWidth - thumbSize - 6
    }

    private func arrowOpacity(for index: Int) -> Double {
        let progress = offset / maxOffset
        let threshold = Double(index) / 3.0
        return progress > threshold ? 0.1 : 0.3
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isCompleted else { return }

                let newOffset = max(0, min(value.translation.width, maxOffset))
                offset = newOffset

                // Haptic feedback at intervals
                let progress = newOffset / maxOffset
                if Int(progress * 10) != Int((offset - value.translation.width) / maxOffset * 10) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.3 + progress * 0.4)
                }
            }
            .onEnded { value in
                guard !isCompleted else { return }

                if offset >= maxOffset * 0.85 {
                    // Complete
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = maxOffset
                        isCompleted = true
                    }

                    // Success haptic
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    // Callback after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                } else {
                    // Spring back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        offset = 0
                    }

                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
    }
}

// MARK: - Preview


