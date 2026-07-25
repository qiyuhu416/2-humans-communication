import SwiftUI

enum AppTheme {
    static let page = Color(red: 0.985, green: 0.978, blue: 0.97)
    static let ink = Color(red: 0.20, green: 0.19, blue: 0.19)
    static let secondaryInk = Color(red: 0.43, green: 0.41, blue: 0.40)
    static let card = Color.white
    static let accent = Color(red: 1.0, green: 0.49, blue: 0.20)
    static let accentSoft = Color(red: 1.0, green: 0.92, blue: 0.86)
    static let questionBackground = Color(red: 1.0, green: 0.965, blue: 0.94)
    static let divider = Color.black.opacity(0.08)
}

struct WarmHorizon: View {
    var expanded = false

    var body: some View {
        GeometryReader { proxy in
            Ellipse()
                .fill(AppTheme.accent)
                .frame(
                    width: expanded ? proxy.size.width * 3.2 : proxy.size.width * 1.55,
                    height: expanded ? proxy.size.height * 3.2 : proxy.size.height * 0.42
                )
                .position(
                    x: proxy.size.width / 2,
                    y: expanded ? proxy.size.height / 2 : proxy.size.height * 1.04
                )
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

struct LayeredWarmBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(red: 1.0, green: 0.72, blue: 0.08)

                Ellipse()
                    .fill(Color(red: 1.0, green: 0.82, blue: 0.12))
                    .frame(width: proxy.size.width * 1.7, height: proxy.size.height * 0.48)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.36)

                Ellipse()
                    .fill(Color(red: 1.0, green: 0.90, blue: 0.47))
                    .frame(width: proxy.size.width * 1.75, height: proxy.size.height * 0.62)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.66)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(enabled ? AppTheme.ink : AppTheme.ink.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
