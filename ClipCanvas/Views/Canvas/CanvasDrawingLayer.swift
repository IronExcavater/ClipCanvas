import PencilKit
import SwiftUI

struct CanvasDrawingLayer: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var activeTool: PKTool = PKInkingTool(.pen, color: .label, width: 3)

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.tool = activeTool
        canvas.drawing = drawing
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.tool = activeTool
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
}
