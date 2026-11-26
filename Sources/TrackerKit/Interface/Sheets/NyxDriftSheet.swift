


import SwiftUI



struct NyxDriftSheet<Content: View>: View {

    let showClose: Bool
    let onClose: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var isDragging = false

    init(
        showClose: Bool = true,
        onClose: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.showClose = showClose
        self.onClose = onClose
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    
                    dragIndicator

                    
                    if showClose {
                        closeButtonRow
                    }

                    
                    content
                        .padding(.horizontal, 24)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 24))
                }
                .background(sheetBackground)
                .clipShape(NyxMapleCorner(radius: 32, corners: [.topLeft, .topRight]))
                .offset(y: offset)
                .gesture(dragGesture)
            }
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    

    private var dragIndicator: some View {
        Capsule()
            .fill(Color.white.opacity(0.3))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private var closeButtonRow: some View {
        HStack {
            Spacer()
            Button(action: {
                hapticLight()
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var sheetBackground: some View {
        Color(red: 0.11, green: 0.11, blue: 0.12)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                if value.translation.height > 0 {
                    offset = value.translation.height
                }
            }
            .onEnded { value in
                isDragging = false
                if value.translation.height > 100 || value.predictedEndTranslation.height > 200 {
                    hapticLight()
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                }
            }
    }

    private func hapticLight() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}



struct NyxMapleCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}



struct NyxStage: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }
}



struct NyxHarbor: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }
}



struct NyxConduit: View {
    let systemName: String
    let color: Color
    let size: CGFloat

    @State private var isAnimating = false

    init(_ systemName: String, color: Color = .blue, size: CGFloat = 60) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size + 30, height: size + 30)

            Circle()
                .fill(color)
                .frame(width: size, height: size)

            Image(systemName: systemName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundColor(.white)
        }
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}



struct NyxPortalButton: View {
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
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(NyxDispatcherTheme.Colors.accent)
            .cornerRadius(16)
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
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



struct NyxRangerButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: {
            haptic()
            action()
        }) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
    }

    private func haptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}



