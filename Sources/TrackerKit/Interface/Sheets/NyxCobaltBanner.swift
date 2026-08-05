// NyxCobaltBanner.swift
// Top banner with swipe-to-change-icon slider and countdown timer

import SwiftUI

struct NyxCobaltBanner: View {

    let iconName: String
    let duration: TimeInterval
    let onSwipeCompleted: () -> Void
    let onExpired: () -> Void
    let onDismiss: () -> Void

    @State private var sliderOffset: CGFloat = 0
    @State private var sliderWidth: CGFloat = 0
    @State private var trackWidth: CGFloat = 280
    @State private var timeRemaining: TimeInterval
    @State private var isCompleted = false
    @State private var isVisible = true
    @State private var timer: Timer?

    private let thumbSize: CGFloat = 48
    private let trackHeight: CGFloat = 56

    init(
        iconName: String,
        duration: TimeInterval = 5,
        onSwipeCompleted: @escaping () -> Void,
        onExpired: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.iconName = iconName
        self.duration = duration
        self.onSwipeCompleted = onSwipeCompleted
        self.onExpired = onExpired
        self.onDismiss = onDismiss
        self._timeRemaining = State(initialValue: duration)
    }

    var body: some View {
        VStack {
            if isVisible {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Banner Content

    private var bannerContent: some View {
        VStack(spacing: 12) {
            // Header: icon + title + timer
            HStack(spacing: 12) {
                // App icon preview
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: iconGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)

                    Text(iconLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: iconGradientColors.first?.opacity(0.5) ?? .clear, radius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Exclusive Icon")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("Swipe to activate")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Countdown timer
                timerView
            }

            // Swipe slider
            swipeSlider
        }
        .padding(16)
        .background(bannerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Timer View

    private var timerView: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: timeRemaining / duration)
                .stroke(
                    timerColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: timeRemaining)

            Text("\(Int(ceil(timeRemaining)))")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
        }
    }

    private var timerColor: Color {
        if timeRemaining > 3 {
            return Color(red: 0.3, green: 0.85, blue: 0.4)
        } else if timeRemaining > 1 {
            return .yellow
        } else {
            return .red
        }
    }

    // MARK: - Swipe Slider

    private var swipeSlider: some View {
        GeometryReader { geo in
            let maxOffset = geo.size.width - thumbSize - 8

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: trackHeight)

                // Progress fill
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.3),
                                Color(red: 0.3, green: 0.85, blue: 0.4).opacity(0.1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: sliderOffset + thumbSize + 8, height: trackHeight)

                // Hint text
                if sliderOffset < maxOffset * 0.3 {
                    HStack {
                        Spacer()
                        Text("slide to change icon →")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.leading, thumbSize + 8)
                }

                // Thumb
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: iconGradientColors.first?.opacity(0.5) ?? .clear, radius: 6)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: sliderOffset + 4)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isCompleted else { return }
                            let newOffset = max(0, min(value.translation.width, maxOffset))
                            sliderOffset = newOffset

                            // Haptic ticks at 25%, 50%, 75%
                            let progress = newOffset / maxOffset
                            if progress > 0.25 && progress < 0.3 ||
                               progress > 0.5 && progress < 0.55 ||
                               progress > 0.75 && progress < 0.8 {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                        .onEnded { value in
                            guard !isCompleted else { return }
                            let progress = sliderOffset / maxOffset
                            if progress > 0.85 {
                                completeSwipe()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    sliderOffset = 0
                                }
                            }
                        }
                )
            }
            .onAppear {
                trackWidth = geo.size.width
            }
        }
        .frame(height: trackHeight)
    }

    // MARK: - Helpers

    private var bannerBackground: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.12)

            // Subtle gradient glow
            LinearGradient(
                colors: [
                    iconGradientColors.first?.opacity(0.1) ?? .clear,
                    .clear,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var iconGradientColors: [Color] {
        switch iconName {
        case "icon_white":
            return [Color(red: 0.85, green: 0.85, blue: 0.9), Color(red: 0.6, green: 0.6, blue: 0.7)]
        case "icon_dark":
            return [Color(red: 0.3, green: 0.3, blue: 0.4), Color(red: 0.15, green: 0.15, blue: 0.2)]
        case "icon_bonus":
            return [Color(red: 1.0, green: 0.75, blue: 0.0), Color(red: 1.0, green: 0.45, blue: 0.0)]
        default:
            return [Color(red: 0.58, green: 0.28, blue: 0.98), Color(red: 0.42, green: 0.85, blue: 0.56)]
        }
    }

    private var iconLabel: String {
        switch iconName {
        case "icon_white": return "W"
        case "icon_dark": return "D"
        case "icon_bonus": return "★"
        default: return "?"
        }
    }

    // MARK: - Actions

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                timeRemaining -= 0.1
                if timeRemaining <= 0 {
                    timer?.invalidate()
                    if !isCompleted {
                        dismiss()
                        onExpired()
                    }
                }
            }
        }
    }

    private func completeSwipe() {
        isCompleted = true
        timer?.invalidate()

        // Success haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Animate thumb to end
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            sliderOffset = trackWidth - thumbSize - 8
        }

        // Dismiss after a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onSwipeCompleted()
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }
}

// MARK: - Preview

