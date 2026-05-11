//
//  DrawingTestView.swift
//  ClipCanvas
//
//  Created by Noel Galan on 11/5/2026.
//
import SwiftUI
import PencilKit

struct DrawingTestView: UIViewRepresentable {
    let isActive: Bool
    let canvasOffset: CGSize
    let canvasScale: CGFloat
    let boardSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()

        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: .black, width: 8)

        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
    
        if abs(canvas.zoomScale - canvasScale) > 0.001 {
            canvas.setZoomScale(canvasScale, animated: false)
        }
        let desiredOffset = CGPoint(
            x: -canvasOffset.width,
            y: -canvasOffset.height
        )

        if abs(canvas.contentOffset.x - desiredOffset.x) + abs(canvas.contentOffset.y - desiredOffset.y) > 0.5 {
            canvas.setContentOffset(desiredOffset, animated: false)
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

    final class Coordinator {
        let toolPicker = PKToolPicker()
    }
}
