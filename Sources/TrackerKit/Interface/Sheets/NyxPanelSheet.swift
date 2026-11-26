


import AVFoundation
import SwiftUI
import UIKit

struct NyxPanelSheet: View {

    let mediaURL: URL
    let mediaType: String
    let adID: Int?
    let advertiserName: String
    let targetingDisclosure: String
    let autoCloseSec: Int
    let onReport: (String) -> Void
    let onClose: () -> Void

    @State private var startDate = Date()
    @State private var didAutoClose = false
    @State private var showTargetingInfo = false
    @State private var showReportMenu = false
    @State private var showReportThanks = false

    private var autoClose: TimeInterval { max(5, TimeInterval(autoCloseSec)) }
    private var isVideo: Bool { mediaType.lowercased() == "video" }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            mediaView
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                Spacer()
                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { now in
            guard !showTargetingInfo, !showReportMenu, !showReportThanks else { return }
            let elapsed = now.timeIntervalSince(startDate)
            if elapsed >= autoClose, !didAutoClose {
                didAutoClose = true
                onClose()
            }
        }
        .sheet(isPresented: $showTargetingInfo) { targetingSheet }
        .confirmationDialog("Report this advertisement", isPresented: $showReportMenu) {
            reportButton("Inappropriate content")
            reportButton("Not age-appropriate")
            reportButton("Misleading")
            reportButton("Other")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose the reason. Your report helps us keep ads safe.")
        }
        .alert("Thank you", isPresented: $showReportThanks) {
            Button("Done") { onClose() }
        } message: {
            Text("Your report was received and this advertisement was closed.")
        }
        .onAppear { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ADVERTISEMENT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                Text(advertiserName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.white)
                    .background(Color(red: 0.92, green: 0.27, blue: 0.35), in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
            .accessibilityLabel("Close advertisement")
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                footerButton("Why this ad?", icon: "info.circle") { showTargetingInfo = true }
                footerButton("Report Ad", icon: "exclamationmark.bubble") { showReportMenu = true }
            }
            Text("You can close this ad at any time")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(12)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
    }

    private func footerButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(.black)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var targetingSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Why you're seeing this ad", systemImage: "scope")
                        .font(.title2.bold())
                    Text(targetingDisclosure)
                    Label("Sensitive personal data is never used to select this advertisement.", systemImage: "lock.shield.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Divider()
                    Text("Advertiser")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(advertiserName).font(.headline)
                }
                .frame(maxWidth: 560, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Ad Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { showTargetingInfo = false } }
        }
        .presentationDetents([.medium, .large])
    }

    private func reportButton(_ reason: String) -> some View {
        Button(reason) {
            onReport(reason)
            showReportThanks = true
        }
    }

    @ViewBuilder
    private var mediaView: some View {
        if isVideo {
            NyxRoster(url: mediaURL)
        } else {
            AsyncImage(url: mediaURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty:
                    ProgressView().tint(.white)
                case .failure:
                    fallbackCreative
                @unknown default:
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
    }

    private var fallbackCreative: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.10, blue: 0.62), Color(red: 1.0, green: 0.24, blue: 0.48), Color.orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                Image(systemName: "sparkles").font(.system(size: 54, weight: .bold))
                Text("Cherry Ads").font(.system(size: 38, weight: .black, design: .rounded))
                Text("Compliance preview").font(.title3.weight(.semibold))
            }
            .foregroundStyle(.white)
        }
    }
}



struct NyxRoster: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> NyxLedgerView {
        NyxLedgerView(url: url)
    }

    func updateUIView(_ uiView: NyxLedgerView, context: Context) {}

    final class NyxLedgerView: UIView {
        private let player: AVPlayer
        private let playerLayer = AVPlayerLayer()
        private var loopObserver: NSObjectProtocol?

        init(url: URL) {
            player = AVPlayer(url: url)
            super.init(frame: .zero)
            player.isMuted = true
            player.actionAtItemEnd = .none
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            layer.addSublayer(playerLayer)
            player.play()

            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero)
                player?.play()
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }

        deinit {
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }
        }
    }
}
