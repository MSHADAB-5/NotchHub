import SwiftUI

/// Reusable dark card used by all widgets inside the notch panel.
/// Uses layered dark surfaces with subtle highlights for a modern dense UI.
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.13, green: 0.13, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(.white.opacity(0.03), lineWidth: 1)
                            .blur(radius: 0.2)
                    }
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12, padding: CGFloat = 14) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
