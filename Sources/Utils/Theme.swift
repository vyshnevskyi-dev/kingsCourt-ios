import SwiftUI

enum Theme {
    static let primaryColor = Color(hex: "#D32F2F")
    // Ink/text color. Was #212121 (near-black, for text on the old white
    // background) — flipped to a warm ivory so the same 24 call sites
    // (body/heading text + low-opacity tint fills) stay legible now that
    // backgroundColor/cardBackground are dark instead of white.
    static let secondaryColor = Color(hex: "#EDE4D3")
    static let backgroundColor = Color(hex: "#151515")
    static let cardBackground = Color(hex: "#212121")
    static let goldColor = Color(hex: "#FFD700")
    static let silverColor = Color(hex: "#C0C0C0")
    static let bronzeColor = Color(hex: "#CD7F32")
    
    static let titleFont = Font.system(size: 28, weight: .bold, design: .rounded)
    static let headlineFont = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .rounded)
    static let captionFont = Font.system(size: 13, weight: .medium, design: .rounded)
}
