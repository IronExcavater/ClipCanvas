import PencilKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension CanvasContainerView {

    var pencilTool: PKTool {
        switch activeDrawTool {
        case .pen:       return PKInkingTool(.pen,    color: penColor,        width: penWidth)
        case .highlighter: return PKInkingTool(.marker, color: highlighterColor, width: highlighterWidth)
        case .eraser:    return PKEraserTool(.fixedWidthBitmap, width: eraserWidth)
        case .lasso:     return PKLassoTool()
        }
    }

    func drawColor(for tool: CanvasDrawTool) -> PlatformColor? {
        switch tool {
        case .pen:         return penColor
        case .highlighter: return highlighterColor
        case .eraser, .lasso: return nil
        }
    }

    func drawWidth(for tool: CanvasDrawTool) -> CGFloat {
        switch tool {
        case .pen:         return penWidth
        case .highlighter: return highlighterWidth
        case .eraser:      return eraserWidth
        case .lasso:       return 0
        }
    }

    func setDrawColor(_ color: PlatformColor, for tool: CanvasDrawTool) {
        switch tool {
        case .pen:         penColor = color
        case .highlighter: highlighterColor = color.withAlphaComponent(0.5)
        case .eraser, .lasso: break
        }
    }

    func setDrawWidth(_ width: CGFloat, for tool: CanvasDrawTool) {
        switch tool {
        case .pen:         penWidth = width
        case .highlighter: highlighterWidth = width
        case .eraser:      eraserWidth = width
        case .lasso:       break
        }
    }

    func leaveMode() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            mode = .pan
            editingObjectID = nil
            drawToolSettings = nil
        }
    }

    func closeToolbarMode() {
        if editingObjectID == nil { leaveMode() } else { exitEditing() }
    }

    func selectDrawTool(_ tool: CanvasDrawTool) {
        activeDrawTool = tool
        if drawToolSettings != nil {
            drawToolSettings = tool.supportsSettings ? tool : nil
        }
    }

    func toggleDrawToolSettings(_ tool: CanvasDrawTool) {
        drawToolSettings = drawToolSettings == tool ? nil : tool
    }
}
