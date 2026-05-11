import SwiftUI
import PencilKit

// UIViewRepresentable is a bridge that lets you embed any UIKit view inside SwiftUI.
// SwiftUI is declarative (describe what you want); UIKit is imperative (set properties, call methods).
// PencilKit's PKCanvasView is UIKit-only, so we need this bridge to use it in our SwiftUI app.
struct DrawingTestView: UIViewRepresentable {
    let isActive: Bool          // controlled by the Draw/Done toggle in CanvasSurface
    let canvasOffset: CGSize    // mirrors the SwiftUI canvas pan offset
    let canvasScale: CGFloat    // mirrors the SwiftUI canvas zoom scale
    let boardSize: CGSize

    // makeCoordinator creates a helper object that outlives individual view updates.
    // We use it here to hold the PKToolPicker, which must stay alive as long as drawing is active.
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // makeUIView is called ONCE when the view is first inserted into the hierarchy.
    // Return the UIKit view you want to display. Think of it like a constructor for the UIKit side.
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()

        canvas.backgroundColor = .clear     // transparent so the dot grid shows through
        canvas.isOpaque = false             // required for transparency to work in UIKit
        canvas.drawingPolicy = .anyInput    // accept touch and Apple Pencil (not pencil-only)
        canvas.tool = PKInkingTool(.pen, color: .black, width: 8)   // default drawing tool

        return canvas
    }

    // updateUIView is called every time SwiftUI re-renders this view with new state.
    // Here we sync the PKCanvasView's scroll/zoom with the SwiftUI canvas pan/zoom.
    // PKCanvasView is a UIScrollView subclass, so zoom/offset are set via UIScrollView APIs.
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.backgroundColor = .clear
        canvas.isOpaque = false

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

    // Coordinator is a plain Swift class that acts as a stable storage across view updates.
    // We hold the PKToolPicker here because it must not be recreated on every render —
    // recreating it would dismiss the floating toolbar mid-draw.
    final class Coordinator {
        let toolPicker = PKToolPicker()
    }
}
