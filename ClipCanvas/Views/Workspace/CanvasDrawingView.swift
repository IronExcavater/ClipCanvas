import SwiftUI
import PencilKit

struct CanvasDrawingView: UIViewRepresentable {
    let isActive: Bool
    @Binding var drawing: PKDrawing
    // Integer bumped by the parent only when drawing content actually changes.
    // Comparing an Int is O(1); comparing PKDrawing data is O(drawing size) and was
    // previously called on every pan/zoom frame — the main source of drawing lag.
    let drawingVersion: Int
    let canvasOffset: CGSize
    let canvasScale: CGFloat
    let boardSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        // Static configuration — kept out of updateUIView so it only runs once.
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 8)
        canvas.delegate = context.coordinator
        canvas.minimumZoomScale = 0.35
        canvas.maximumZoomScale = 3
        canvas.contentSize = boardSize
        canvas.bounces = false
        canvas.bouncesZoom = false
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false
        canvas.contentInset = .zero
        canvas.scrollIndicatorInsets = .zero
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.delaysContentTouches = false
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.drawing = $drawing

        // Reload the PKDrawing into the canvas only when the version changes.
        // This is the key performance fix — previously every pan/zoom called
        // drawing.dataRepresentation() which serialises the whole drawing on the main thread.
        if context.coordinator.appliedVersion != drawingVersion {
            canvas.drawing = drawing
            context.coordinator.appliedVersion = drawingVersion
        }

        // Sync zoom — guard avoids redundant UIKit calls during normal pan.
        if abs(canvas.zoomScale - canvasScale) > 0.001 {
            canvas.setZoomScale(canvasScale, animated: false)
        }

        // SwiftUI offset is opposite sign to UIKit contentOffset.
        let target = CGPoint(x: -canvasOffset.width, y: -canvasOffset.height)
        if abs(canvas.contentOffset.x - target.x) + abs(canvas.contentOffset.y - target.y) > 0.5 {
            canvas.setContentOffset(target, animated: false)
        }

        guard canvas.window != nil else { return }

        if isActive {
            context.coordinator.toolPicker.addObserver(canvas)
            context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        } else {
            context.coordinator.toolPicker.setVisible(false, forFirstResponder: canvas)
            canvas.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let toolPicker = PKToolPicker()
        var drawing: Binding<PKDrawing>
        var appliedVersion: Int = -1    // -1 forces the first load

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Write the new drawing back to the parent binding.
            // The parent bumps drawingVersion in response, which will be picked
            // up by the next updateUIView — no data comparison needed here.
            drawing.wrappedValue = canvasView.drawing
        }
    }
}
