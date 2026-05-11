import SwiftUI
import PencilKit

struct CanvasDrawingView: UIViewRepresentable {
    let isActive: Bool          // controlled by the Draw/Done toggle in CanvasSurface
    @Binding var drawing: PKDrawing
    let canvasOffset: CGSize    // mirrors the SwiftUI canvas pan offset
    let canvasScale: CGFloat    // mirrors the SwiftUI canvas zoom scale
    let boardSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()

        canvas.backgroundColor = .clear     // transparent so the dot grid shows through
        canvas.isOpaque = false             // required for transparency to work in UIKit
        canvas.drawingPolicy = .anyInput    // accept touch and Apple Pencil (not pencil-only)
        canvas.tool = PKInkingTool(.pen, color: .black, width: 8)   // default drawing tool
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
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.contentSize = boardSize
        canvas.minimumZoomScale = 0.35
        canvas.maximumZoomScale = 3
        canvas.bounces = false
        canvas.bouncesZoom = false
        canvas.contentInset = .zero
        canvas.scrollIndicatorInsets = .zero
        canvas.contentInsetAdjustmentBehavior = .never

        let drawingData = drawing.dataRepresentation()
        if context.coordinator.appliedDrawingData != drawingData {
            canvas.drawing = drawing
            context.coordinator.appliedDrawingData = drawingData
        }

        // Only update zoom if it's actually changed — avoids triggering unnecessary scroll events.
        if abs(canvas.zoomScale - canvasScale) > 0.001 {
            canvas.setZoomScale(canvasScale, animated: false)
        }

        // SwiftUI uses "offset" (positive = moved right/down); UIScrollView uses contentOffset
        // (positive = scrolled right/down, but from the view's perspective that means content
        // appears shifted left/up). So we negate the SwiftUI offset to get UIKit's contentOffset.
        let desiredOffset = CGPoint(x: -canvasOffset.width, y: -canvasOffset.height)
        if abs(canvas.contentOffset.x - desiredOffset.x) + abs(canvas.contentOffset.y - desiredOffset.y) > 0.5 {
            canvas.setContentOffset(desiredOffset, animated: false)
        }

        // Ensure the view is attached to a window before touching the tool picker —
        // PKToolPicker requires a window to anchor its floating UI.
        guard canvas.window != nil else { return }

        if isActive {
            // addObserver tells the tool picker which canvas should reflect its selection.
            // setVisible shows the floating pencil toolbar; it only appears when the canvas
            // is the first responder (i.e., focused and ready to accept input).
            context.coordinator.toolPicker.addObserver(canvas)
            context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()   // claims keyboard/pencil focus
        } else {
            context.coordinator.toolPicker.setVisible(false, forFirstResponder: canvas)
            canvas.resignFirstResponder()   // releases focus so pan/zoom gestures resume
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let toolPicker = PKToolPicker()
        var drawing: Binding<PKDrawing>
        var appliedDrawingData: Data?

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            appliedDrawingData = canvasView.drawing.dataRepresentation()
            drawing.wrappedValue = canvasView.drawing
        }
    }
}
