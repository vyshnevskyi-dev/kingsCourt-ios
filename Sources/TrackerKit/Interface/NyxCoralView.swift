










import SwiftUI
import UIKit

struct NyxCoralView: View {

    let payload: NyxForge

    @State private var didOpenStore = false

    var body: some View {
        ZStack {
            NyxDispatcherTheme.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    blockedTitleView(payload.title)

                    Text(payload.message)
                        .font(.system(size: 17))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 0)

                Button(action: openStore) {
                    Text(payload.buttonText)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NyxDispatcherTheme.Colors.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        
        
        
        
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        .statusBar(hidden: true)
        .interactiveDismissDisabled(true)
    }

    @ViewBuilder
    private func blockedTitleView(_ title: String) -> some View {
        let parts = title.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count >= 2 {
            Text(parts[0]).foregroundStyle(.white).font(.system(size: 28, weight: .bold))
            + Text(" ") + Text(parts[1]).foregroundStyle(NyxDispatcherTheme.Colors.accent).font(.system(size: 28, weight: .bold))
        } else {
            Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func openStore() {
        guard let url = payload.url else {
            NyxMint.error("Block screen: invalid button URL \(payload.buttonURL)", nil)
            return
        }
        didOpenStore = true
        UIApplication.shared.open(url)
    }
}
