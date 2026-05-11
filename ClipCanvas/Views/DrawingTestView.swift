//
//  DrawingTestView.swift
//  ClipCanvas
//
//  Created by Noel Galan on 11/5/2026.
//
import SwiftUI
import PencilKit

struct DrawingTestView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .black, width: 8)

        DispatchQueue.main.async {
            context.coordinator.toolPicker.addObserver(canvas)
            context.coordinator.toolPicker.setVisible(true, forFirstResponder: canvas)
            canvas.becomeFirstResponder()
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) { }

    class Coordinator {
        let toolPicker = PKToolPicker()
    }
}
