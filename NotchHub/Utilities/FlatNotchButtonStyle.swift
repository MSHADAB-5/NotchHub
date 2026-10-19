import SwiftUI

struct FlatNotchButtonStyle: ButtonStyle {
    enum ShapeKind {
        case rounded(CGFloat)
        case capsule
        case circle
    }

    var shape: ShapeKind = .rounded(8)
    var strokeColor: Color? = nil
    var strokeWidth: CGFloat = 0.5
    var hoverFillColor: Color = .white.opacity(0.04)

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(
            configuration: configuration,
            shape: shape,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            hoverFillColor: hoverFillColor
        )
    }

    private struct HoverBody: View {
        let configuration: Configuration
        let shape: ShapeKind
        let strokeColor: Color?
        let strokeWidth: CGFloat
        let hoverFillColor: Color
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background(backgroundView)
                .overlay(borderView)
                .opacity(configuration.isPressed ? 0.72 : 1.0)
                .contentShape(Rectangle())
                .onHover { isHovered = $0 }
        }

        @ViewBuilder
        private var backgroundView: some View {
            let fill = (isHovered || configuration.isPressed) ? hoverFillColor : Color.clear
            switch shape {
            case .rounded(let radius):
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            case .capsule:
                Capsule(style: .circular).fill(fill)
            case .circle:
                Circle().fill(fill)
            }
        }

        @ViewBuilder
        private var borderView: some View {
            if let strokeColor {
                let effective = isHovered ? strokeColor.opacity(1.25) : strokeColor
                switch shape {
                case .rounded(let radius):
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(effective, lineWidth: strokeWidth)
                case .capsule:
                    Capsule(style: .circular)
                        .strokeBorder(effective, lineWidth: strokeWidth)
                case .circle:
                    Circle()
                        .strokeBorder(effective, lineWidth: strokeWidth)
                }
            }
        }
    }
}
