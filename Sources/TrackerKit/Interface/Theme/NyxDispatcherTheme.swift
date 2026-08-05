// NyxDispatcherTheme.swift
// Application visual theme

import SwiftUI

enum NyxDispatcherTheme {

    // MARK: - Colors

    enum Colors {
        // Backgrounds
        static let background = Color(red: 0.08, green: 0.08, blue: 0.12)
        static let backgroundSecondary = Color(red: 0.12, green: 0.12, blue: 0.18)
        static let surface = Color(red: 0.14, green: 0.14, blue: 0.20)

        // Accent colors
        // Brand accent — Wild Cherry #EB455A
        static let accent = Color(red: 0.922, green: 0.271, blue: 0.353)
        static let accentLight = Color(red: 0.98, green: 0.48, blue: 0.55)
        static let accentSecondary = Color(red: 0.20, green: 0.85, blue: 0.65)

        // Gradient colors — warm reds
        static let gradientStart = Color(red: 0.98, green: 0.30, blue: 0.38)
        static let gradientMid = Color(red: 0.922, green: 0.271, blue: 0.353)
        static let gradientEnd = Color(red: 0.85, green: 0.20, blue: 0.30)

        // Text
        static let textPrimary = Color.white
        static let textSecondary = Color.white.opacity(0.7)
        static let textMuted = Color.white.opacity(0.5)

        // States
        static let success = Color(red: 0.20, green: 0.85, blue: 0.45)
        static let warning = Color(red: 1.0, green: 0.75, blue: 0.25)
        static let error = Color(red: 1.0, green: 0.35, blue: 0.35)

        // Borders
        static let border = Color.white.opacity(0.1)
    }

    // MARK: - Gradients

    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.gradientStart, Colors.gradientMid, Colors.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accent = LinearGradient(
            colors: [Colors.accent, Colors.accent.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xlarge: CGFloat = 24
    }

    // MARK: - Animation

    enum Animation {
        static let fast = SwiftUI.Animation.easeOut(duration: 0.15)
        static let normal = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.75)
    }
}

// MARK: - View Extensions

extension View {

    func cardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: NyxDispatcherTheme.Radius.xlarge)
                    .fill(NyxDispatcherTheme.Colors.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: NyxDispatcherTheme.Radius.xlarge)
                            .stroke(NyxDispatcherTheme.Colors.border, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }
}
