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
        applyViewport(to: canvas)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = activeTool
        uiView.contentSize = worldSize
        uiView.minimumZoomScale = canvasScale
        uiView.maximumZoomScale = canvasScale
        if abs(uiView.zoomScale - canvasScale) > 0.001 {
            uiView.setZoomScale(canvasScale, animated: false)
        }
        applyViewport(to: uiView)
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

    private func applyViewport(to canvas: PKCanvasView) {
        let nextOffset = CGPoint(
            x: (viewportOrigin.x + worldOrigin.x) * canvasScale,
            y: (viewportOrigin.y + worldOrigin.y) * canvasScale
        )
        guard hypot(canvas.contentOffset.x - nextOffset.x, canvas.contentOffset.y - nextOffset.y) > 0.5 else {
            return
        }
        canvas.setContentOffset(nextOffset, animated: false)
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
