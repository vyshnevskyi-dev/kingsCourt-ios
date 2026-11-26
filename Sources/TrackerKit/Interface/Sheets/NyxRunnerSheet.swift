


import SwiftUI

struct NyxRunnerSheet: View {

    let privacyURL: URL?
    let termsURL: URL?
    let onAgree: () -> Void
    let onClose: () -> Void

    var body: some View {
        NyxDriftSheet(onClose: onClose) {
            VStack(spacing: 20) {
                NyxConduit("doc.text.fill", color: NyxDispatcherTheme.Colors.accent)

                NyxStage(text: "Terms & Privacy")

                NyxHarbor(text: "Please review our Terms of Service and Privacy Policy before continuing.")

                HStack(spacing: 24) {
                    if let termsURL {
                        legalLink("Terms of Service", url: termsURL)
                    }
                    if let privacyURL {
                        legalLink("Privacy Policy", url: privacyURL)
                    }
                }
                .padding(.vertical, 4)

                NyxWidgetSlider {
                    onAgree()
                    onClose()
                }
                .padding(.top, 8)

                NyxRangerButton("Decline") {
                    onClose()
                }
            }
            .padding(.top, 8)
        }
        .transition(.move(edge: .bottom))
    }

    private func legalLink(_ title: String, url: URL) -> some View {
        Button {
            UIApplication.shared.open(url, options: [:])
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "safari")
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .underline()
            }
            .foregroundColor(NyxDispatcherTheme.Colors.accent)
        }
        .accessibilityHint("Opens in Safari")
    }
}



struct NyxWidgetSlider: View {

    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isCompleted = false

    private let sliderWidth: CGFloat = 280
    private let thumbSize: CGFloat = 54
    private let trackHeight: CGFloat = 60

    var body: some View {
        ZStack(alignment: .leading) {
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .frame(width: sliderWidth, height: trackHeight)

            
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

            
            HStack {
                Spacer()
                Text("Swipe to agree")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(1 - Double(offset / maxOffset) * 2)
                Spacer()
            }
            .frame(width: sliderWidth)

            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .opacity(arrowOpacity(for: index))
                }
            }
            .offset(x: thumbSize + 16)

            
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

                
                let progress = newOffset / maxOffset
                if Int(progress * 10) != Int((offset - value.translation.width) / maxOffset * 10) {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred(intensity: 0.3 + progress * 0.4)
                }
            }
            .onEnded { value in
                guard !isCompleted else { return }

                if offset >= maxOffset * 0.85 {
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = maxOffset
                        isCompleted = true
                    }

                    
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                } else {
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        offset = 0
                    }

                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
    }
}



