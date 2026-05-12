import SwiftData
import SwiftUI
import PencilKit

struct CanvasSurface: View {
    let workspace: Workspace?
    @Binding var selectedCardIDs: Set<UUID>
    @Binding var editingCard: WorkspaceCard?
    let runningTransforms: Set<UUID>
    let openChatForCard: (WorkspaceCard) -> Void
    let copyCard: (WorkspaceCard) -> Void
    let deleteCard: (WorkspaceCard) -> Void
    let duplicateCard: (WorkspaceCard) -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void
    let addDroppedContent: (SnippetDragPayload, CGPoint) -> Void

    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var dragState = CanvasDragState()
    @State private var drawingModeActive = false

    private let boardSize = CGSize(width: 5000, height: 5000)

    // Reads the active workspace's persisted drawing, decoding it from Data on demand.
    private var activeDrawing: Binding<PKDrawing> {
        Binding {
            guard let data = workspace?.drawingData,
                  let drawing = try? PKDrawing(data: data) else { return PKDrawing() }
            return drawing
        } set: { newValue in
            let data = newValue.dataRepresentation()
            // Store nil when the drawing is empty so hasActiveDrawing stays correct.
            workspace?.drawingData = newValue.bounds.isEmpty ? nil : data
        }
    }

    private var hasActiveDrawing: Bool {
        workspace?.drawingData != nil
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                DotGrid(offset: canvasOffset, scale: canvasScale)
                    .gesture(drawingModeActive ? nil : panGesture)
                    .onTapGesture {
                        if !drawingModeActive { selectedCardIDs.removeAll() }
                    }

                // PencilKit overlay — transparent when drawing is inactive so gestures pass through.
                CanvasDrawingView(
                    isActive: drawingModeActive,
                    drawing: activeDrawing,
                    canvasOffset: canvasOffset,
                    canvasScale: canvasScale,
                    boardSize: boardSize
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Color.clear)
                .allowsHitTesting(drawingModeActive)
                .zIndex(5)

                if let workspace, workspace.cards.isEmpty {
                    EmptyCanvasHint()
                }

                if let workspace {
                    ZStack(alignment: .topLeading) {
                        ForEach(workspace.cards) { card in
                            CanvasCardView(
                                card: card,
                                canvasScale: canvasScale,
                                isSelected: selectedCardIDs.contains(card.id),
                                isRunning: card.transformRun.map { runningTransforms.contains($0.id) } ?? false,
                                selectedCardIDs: selectedCardIDs,
                                dragState: dragState,
                                select: { select(card) },
                                ask: { openChatForCard(card) },
                                edit: { editingCard = card },
                                copy: { copyCard(card) },
                                duplicate: { duplicateCard(card) },
                                delete: { deleteCard(card) },
                                moveCards: moveCards
                            )
                            .position(x: card.x, y: card.y)
                            .zIndex(selectedCardIDs.contains(card.id) ? 20 : (card.transformRun == nil ? 1 : 2))
                        }
                    }
                    .frame(width: boardSize.width, height: boardSize.height, alignment: .topLeading)
                    .scaleEffect(canvasScale, anchor: .topLeading)
                    .offset(canvasOffset)
                    .zIndex(10)
                }

                CanvasControlStrip(
                    scale: canvasScale,
                    canZoomOut: canvasScale > 0.35,
                    canZoomIn: canvasScale < 3,
                    zoomOut: { zoom(by: 0.85, in: proxy) },
                    zoomIn: { zoom(by: 1.15, in: proxy) },
                    fit: { fitWorkspace(in: proxy) },
                    reset: resetView
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18)
                .zIndex(1000)

                drawingControls
                    .padding(.top, 12)
                    .padding(.leading, 12)
                    .zIndex(1000)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .dropDestination(for: SnippetDragPayload.self) { items, location in
                guard let payload = items.first, payload.hasContent else { return false }
                addDroppedContent(payload, canvasPoint(for: location))
                return true
            }
            .dropDestination(for: String.self) { items, location in
                guard let text = items.first?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    return false
                }
                addDroppedContent(SnippetDragPayload(text: text, imageData: nil), canvasPoint(for: location))
                return true
            }
            .clipped()
            .simultaneousGesture(drawingModeActive ? nil : zoomGesture(proxy: proxy))
            .onChange(of: workspace?.id) { _, _ in
                // Deactivate drawing when switching workspaces so the new workspace
                // loads its own drawing fresh without the old tool picker showing.
                drawingModeActive = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .localDataReset)) { _ in
                // When all local data is cleared, wipe the active workspace drawing and
                // reset drawing mode. Other workspaces are cleaned up by SwiftData cascade.
                workspace?.drawingData = nil
                drawingModeActive = false
            }
        }
        .background(Color.clipCanvasPageBackground)
    }

    // MARK: Drawing controls

    private var drawingControls: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.snappy(duration: 0.14)) { drawingModeActive.toggle() }
            } label: {
                Label(
                    drawingModeActive ? "Done" : "Draw",
                    systemImage: drawingModeActive ? "checkmark.circle.fill" : "pencil.tip"
                )
            }
            .foregroundStyle(drawingModeActive ? Color.accentColor : .primary)

            if hasActiveDrawing {
                Button(role: .destructive, action: clearActiveDrawing) {
                    Image(systemName: "eraser")
                }
                .help("Clear drawing")
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: Card selection

    private func select(_ card: WorkspaceCard) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    // MARK: Pan & zoom

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                canvasOffset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in baseOffset = canvasOffset }
    }

    private func zoomGesture(proxy: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let nextScale = clampedScale(baseScale * value)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                canvasOffset = CGSize(
                    width: center.x - (center.x - baseOffset.width) * nextScale / baseScale,
                    height: center.y - (center.y - baseOffset.height) * nextScale / baseScale
                )
                canvasScale = nextScale
            }
            .onEnded { _ in
                baseScale = canvasScale
                baseOffset = canvasOffset
            }
    }

    private func zoom(by factor: CGFloat, in proxy: GeometryProxy) {
        let nextScale = clampedScale(canvasScale * factor)
        let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
        let nextOffset = CGSize(
            width: center.x - (center.x - canvasOffset.width) * nextScale / canvasScale,
            height: center.y - (center.y - canvasOffset.height) * nextScale / canvasScale
        )
        withAnimation(.snappy(duration: 0.16)) {
            canvasScale = nextScale
            baseScale = nextScale
            canvasOffset = nextOffset
            baseOffset = nextOffset
        }
    }

    private func fitWorkspace(in proxy: GeometryProxy) {
        guard let cards = workspace?.cards, !cards.isEmpty else {
            resetView()
            return
        }
        let bounds = cards.reduce(CGRect.null) { rect, card in
            rect.union(CGRect(
                x: CGFloat(card.x - card.width / 2),
                y: CGFloat(card.y - card.height / 2),
                width: CGFloat(card.width),
                height: CGFloat(card.height)
            ))
        }
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }

        let padding: CGFloat = 96
        let availableWidth  = max(proxy.size.width  - padding, 240)
        let availableHeight = max(proxy.size.height - padding, 180)
        let nextScale = min(max(min(availableWidth / bounds.width, availableHeight / bounds.height), 0.35), 1.35)
        let nextOffset = CGSize(
            width:  proxy.size.width  / 2 - bounds.midX * nextScale,
            height: proxy.size.height / 2 - bounds.midY * nextScale
        )
        withAnimation(.snappy(duration: 0.22)) {
            canvasScale  = nextScale
            baseScale    = nextScale
            canvasOffset = nextOffset
            baseOffset   = nextOffset
        }
    }

    private func resetView() {
        withAnimation(.snappy(duration: 0.18)) {
            canvasOffset = .zero
            baseOffset   = .zero
            canvasScale  = 1
            baseScale    = 1
        }
    }

    private func clearActiveDrawing() {
        workspace?.drawingData = nil
        withAnimation(.snappy(duration: 0.14)) { drawingModeActive = false }
    }

    private func canvasPoint(for location: CGPoint) -> CGPoint {
        CGPoint(
            x: (location.x - canvasOffset.width)  / canvasScale,
            y: (location.y - canvasOffset.height) / canvasScale
        )
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat { min(max(scale, 0.35), 3) }
}

@Observable
final class CanvasDragState {
    var selectionOffset: CGSize = .zero
}

private struct DotGrid: View {
    let offset: CGSize
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing = max(24 * scale, 12)
            let radius = min(1.2 * scale, 2)
            var x = offset.width.truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }
            while x < size.width + spacing {
                var y = offset.height.truncatingRemainder(dividingBy: spacing)
                if y < 0 { y += spacing }
                while y < size.height + spacing {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.secondary.opacity(0.22))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

private struct EmptyCanvasHint: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.3.group.bubble.left")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("Empty canvas")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

private extension SnippetDragPayload {
    var hasContent: Bool {
        imageData != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
