import PencilKit
import SwiftUI

#if canImport(UIKit)
struct CanvasDrawingLayer: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var activeTool: PKTool = PKInkingTool(.pen, color: .label, width: 3)
    var viewportOrigin: CGPoint = .zero
    var canvasScale: CGFloat = 1
    var worldOrigin: CGPoint = CGPoint(x: 1_200, y: 1_200)
    var worldSize: CGSize = CGSize(width: 2_400, height: 2_400)

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.bounces = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.minimumZoomScale = canvasScale
        canvas.maximumZoomScale = canvasScale
        canvas.contentSize = worldSize
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.tool = activeTool
        canvas.drawing = drawing
        applyViewport(to: canvas, animated: false)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = activeTool
        uiView.contentSize = worldSize
        uiView.minimumZoomScale = canvasScale
        uiView.maximumZoomScale = canvasScale
        applyViewport(to: uiView, animated: context.transaction.animation != nil)
        if uiView.drawing != drawing {
            context.coordinator.isApplyingSwiftUIUpdate = true
            uiView.drawing = drawing
            context.coordinator.isApplyingSwiftUIUpdate = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing
        var isApplyingSwiftUIUpdate = false

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isApplyingSwiftUIUpdate else { return }
            let nextDrawing = canvasView.drawing
            DispatchQueue.main.async { [weak self] in
                self?.drawing = nextDrawing
            }
        }
    }

    private func applyViewport(to canvas: PKCanvasView, animated: Bool) {
        let nextOffset = CGPoint(
            x: (viewportOrigin.x + worldOrigin.x) * canvasScale,
            y: (viewportOrigin.y + worldOrigin.y) * canvasScale
        )

        let applyChanges = {
            if abs(canvas.zoomScale - canvasScale) > 0.001 {
                canvas.zoomScale = canvasScale
            }
            if hypot(canvas.contentOffset.x - nextOffset.x, canvas.contentOffset.y - nextOffset.y) > 0.5 {
                canvas.contentOffset = nextOffset
            }
        }

        if animated {
            UIView.animate(
                withDuration: 0.22,
                delay: 0,
                options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
                animations: applyChanges
            )
        } else {
            applyChanges()
        }
    }
}
#elseif canImport(AppKit)
struct CanvasDrawingLayer: View {
    @Binding var drawing: PKDrawing
    var activeTool: PKTool = PKInkingTool(.pen, color: .label, width: 3)
    var viewportOrigin: CGPoint = .zero
    var canvasScale: CGFloat = 1
    var worldOrigin: CGPoint = CGPoint(x: 1_200, y: 1_200)
    var worldSize: CGSize = CGSize(width: 2_400, height: 2_400)

    var body: some View {
        Color.clear
    }
}
#endif
