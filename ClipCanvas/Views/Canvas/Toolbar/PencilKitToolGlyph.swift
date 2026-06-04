import SwiftUI

struct PencilKitToolGlyph: View {
    let tool: CanvasDrawTool
    let color: PlatformColor?
    let isSelected: Bool

    private var strokeColor: Color { isSelected ? .white : .primary }

    private var fillColor: Color {
        if let color { return Color(platformColor: color) }
        return isSelected ? .white.opacity(0.92) : .primary.opacity(0.78)
    }

    var body: some View {
        Canvas { context, size in
            switch tool {
            case .pen:         drawPen(in: &context, size: size)
            case .highlighter: drawHighlighter(in: &context, size: size)
            case .eraser:      drawEraser(in: &context, size: size)
            case .lasso:       drawLasso(in: &context, size: size)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawPen(in context: inout GraphicsContext, size: CGSize) {
        let body = Path { path in
            path.move(to: CGPoint(x: size.width * 0.72, y: size.height * 0.10))
            path.addLine(to: CGPoint(x: size.width * 0.89, y: size.height * 0.27))
            path.addLine(to: CGPoint(x: size.width * 0.32, y: size.height * 0.84))
            path.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.92))
            path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.74))
            path.closeSubpath()
        }
        context.fill(body, with: .color(fillColor))
        context.stroke(body, with: .color(strokeColor.opacity(0.78)), lineWidth: 1.2)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.60, y: size.height * 0.22))
                path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.40))
            },
            with: .color(strokeColor.opacity(0.9)), lineWidth: 1.2
        )
    }

    private func drawHighlighter(in context: inout GraphicsContext, size: CGSize) {
        let body = Path { path in
            path.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.18))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.18))
            path.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.68))
            path.addLine(to: CGPoint(x: size.width * 0.60, y: size.height * 0.86))
            path.addLine(to: CGPoint(x: size.width * 0.40, y: size.height * 0.86))
            path.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.68))
            path.closeSubpath()
        }
        context.fill(body, with: .color(fillColor.opacity(isSelected ? 0.95 : 0.82)))
        context.stroke(body, with: .color(strokeColor.opacity(0.62)), lineWidth: 1.1)
        let tip = Path { path in
            path.move(to: CGPoint(x: size.width * 0.34, y: size.height * 0.72))
            path.addLine(to: CGPoint(x: size.width * 0.66, y: size.height * 0.72))
            path.addLine(to: CGPoint(x: size.width * 0.58, y: size.height * 0.90))
            path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.90))
            path.closeSubpath()
        }
        context.fill(tip, with: .color(strokeColor.opacity(isSelected ? 0.88 : 0.72)))
    }

    private func drawEraser(in context: inout GraphicsContext, size: CGSize) {
        let eraser = Path { path in
            path.move(to: CGPoint(x: size.width * 0.58, y: size.height * 0.10))
            path.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.42))
            path.addLine(to: CGPoint(x: size.width * 0.46, y: size.height * 0.86))
            path.addLine(to: CGPoint(x: size.width * 0.14, y: size.height * 0.54))
            path.closeSubpath()
        }
        context.fill(eraser, with: .color(isSelected ? .white.opacity(0.94) : Color.platformSystemBackground.opacity(0.95)))
        context.stroke(eraser, with: .color(strokeColor.opacity(0.76)), lineWidth: 1.2)
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.30, y: size.height * 0.70))
                path.addLine(to: CGPoint(x: size.width * 0.76, y: size.height * 0.24))
            },
            with: .color(strokeColor.opacity(0.45)), lineWidth: 1
        )
    }

    private func drawLasso(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        path.addEllipse(in: CGRect(x: size.width * 0.12, y: size.height * 0.16,
                                   width: size.width * 0.72, height: size.height * 0.58))
        context.stroke(path, with: .color(strokeColor.opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.66, y: size.height * 0.66))
                path.addLine(to: CGPoint(x: size.width * 0.88, y: size.height * 0.88))
            },
            with: .color(strokeColor.opacity(0.9)), lineWidth: 2
        )
    }
}
