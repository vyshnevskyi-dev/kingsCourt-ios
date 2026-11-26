


import SwiftUI
import StoreKit

struct NyxSummitSheet: View {

    let onClose: () -> Void

    
    
    
    static let storeReviewThreshold: Int = 4

    @State private var selectedRating: Int = 0
    @State private var showThankYou = false

    var body: some View {
        NyxDriftSheet(showClose: !showThankYou, onClose: {
            sendEvent(.rateSheetClosed, props: selectedRating > 0 ? ["rating": selectedRating] : nil)
            onClose()
        }) {
            if showThankYou {
                thankYouContent
            } else {
                ratingContent
            }
        }
    }

    

    private var ratingContent: some View {
        VStack(spacing: 20) {
            NyxConduit("star.fill", color: Color(red: 1.0, green: 0.8, blue: 0.2))

            NyxStage(text: "Enjoying the App?")

            NyxHarbor(text: "Your feedback helps us improve and create a better experience for everyone.")

            
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { star in
                    NyxGlintButton(
                        filled: star <= selectedRating,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedRating = star
                            }
                            starHaptic()
                        }
                    )
                }
            }
            .padding(.vertical, 12)

            VStack(spacing: 8) {
                NyxPortalButton(primaryCTALabel, icon: "star.fill") {
                    submitRating()
                }
                .opacity(selectedRating > 0 ? 1 : 0.5)
                .disabled(selectedRating == 0)

                NyxRangerButton("Not Now") {
                    sendEvent(.rateSheetClosed, props: selectedRating > 0 ? ["rating": selectedRating] : nil)
                    onClose()
                }
            }
        }
        .padding(.top, 8)
    }

    

    private var thankYouContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.42, green: 0.85, blue: 0.56).opacity(0.15))
                    .frame(width: 90, height: 90)

                Circle()
                    .fill(Color(red: 0.42, green: 0.85, blue: 0.56))
                    .frame(width: 60, height: 60)

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            NyxStage(text: "Thank You!")

            NyxHarbor(text: thankYouSubtitle)

            NyxPortalButton("Continue") {
                onClose()
            }
        }
        .padding(.top, 8)
        .transition(.scale.combined(with: .opacity))
    }

    

    
    
    
    private var triggersStoreReview: Bool {
        selectedRating >= Self.storeReviewThreshold
    }

    private var primaryCTALabel: String {
        triggersStoreReview ? "Rate on App Store" : "Submit Feedback"
    }

    private var thankYouSubtitle: String {
        selectedRating >= Self.storeReviewThreshold
            ? "Your feedback means a lot to us."
            : "Your feedback helps us improve the app."
    }

    

    private func submitRating() {
        let rating = selectedRating
        let forwardToStore = triggersStoreReview

        sendEvent(.rateSliderCompleted, props: [
            "rating": rating,
            "triggered_store_review": forwardToStore,
        ])

        withAnimation(.spring(response: 0.4)) {
            showThankYou = true
        }

        if forwardToStore {
            sendEvent(.rateStoreReviewRequested, props: ["rating": rating])
            
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
        } else {
            sendEvent(.rateLowCaptured, props: ["rating": rating])
        }
    }

    private func sendEvent(_ event: NyxAtlasRequest.NyxStudio, props: [String: Any]? = nil) {
        Task {
            await NyxDispatcherRouter.shared.trackEvent(event, properties: props)
        }
    }

    private func starHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}



private struct NyxGlintButton: View {
    let filled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: filled ? "star.fill" : "star")
                .font(.system(size: 36))
                .foregroundColor(filled ? Color(red: 1.0, green: 0.8, blue: 0.2) : .white.opacity(0.3))
                .scaleEffect(isPressed ? 1.2 : 1.0)
                .animation(.spring(response: 0.2), value: isPressed)
                .animation(.spring(response: 0.2), value: filled)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}



