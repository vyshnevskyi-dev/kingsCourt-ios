// AppButtons.swift
// Reusable button components

import SwiftUI

// MARK: - Primary Button

struct NyxAnchorButton: View {

    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: {
            haptic()
            action()
        }) {
            HStack(spacing: NyxDispatcherTheme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                }
                Text(title)
                    .font(NyxDispatcherTheme.Typography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NyxDispatcherTheme.Spacing.md)
            .padding(.horizontal, NyxDispatcherTheme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: NyxDispatcherTheme.Radius.large)
                    .fill(NyxDispatcherTheme.Gradients.primary)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(NyxDispatcherTheme.Animation.fast, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func haptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Secondary Button

struct NyxMonitorButton: View {

    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NyxDispatcherTheme.Typography.subheadline)
                .foregroundColor(NyxDispatcherTheme.Colors.textSecondary)
                .padding(.vertical, NyxDispatcherTheme.Spacing.sm)
        }
    }
}

// MARK: - Circle Button

struct NyxOrbitButton: View {

    let icon: String
    let size: CGFloat
    let action: () -> Void

    @State private var isPressed = false

    init(_ icon: String, size: CGFloat = 44, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundColor(NyxDispatcherTheme.Colors.textSecondary)
                .frame(width: size, height: size)
                .background(Circle().fill(NyxDispatcherTheme.Colors.surface))
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(NyxDispatcherTheme.Animation.fast, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Destructive Button

struct NyxRelayButton: View {

    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: NyxDispatcherTheme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(NyxDispatcherTheme.Typography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, NyxDispatcherTheme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: NyxDispatcherTheme.Radius.large)
                    .fill(NyxDispatcherTheme.Colors.error)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

