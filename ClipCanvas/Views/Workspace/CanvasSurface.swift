import SwiftData
import SwiftUI
import PencilKit

enum CanvasTool: Equatable {
    case select
    case draw
}

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
    let paste: () -> Void
    let addCard: () -> Void

    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var dragState = CanvasDragState()
    @State private var activeTool: CanvasTool = .select

    @State private var currentDrawing = PKDrawing()
    @State private var drawingVersion = 0
    @State private var saveTask: Task<Void, Never>?

    private let boardSize = CGSize(width: 5000, height: 5000)
    private var drawingModeActive: Bool { activeTool == .draw }
    private var hasActiveDrawing: Bool { !currentDrawing.bounds.isEmpty }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                // Transparent background layer: captures pan + deselect taps
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(drawingModeActive ? nil : panGesture)
                    .onTapGesture {
                        if !drawingModeActive { selectedCardIDs.removeAll() }
                    }

                CanvasDrawingView(
                    isActive: drawingModeActive,
                    drawing: Binding(get: { currentDrawing }, set: { onDrawingChanged($0) }),
                    drawingVersion: drawingVersion,
                    canvasOffset: canvasOffset,
                    canvasScale: canvasScale,
                    boardSize: boardSize
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Color.clear)
                .allowsHitTesting(drawingModeActive)
                .zIndex(5)

                if let workspace, workspace.cards.isEmpty { EmptyCanvasHint() }

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
            .overlay(alignment: .bottom) {
                CanvasBottomBar(
                    activeTool: $activeTool,
                    scale: canvasScale,
                    hasDrawing: hasActiveDrawing,
                    canZoomOut: canvasScale > 0.35,
                    canZoomIn: canvasScale < 3,
                    paste: paste,
                    addCard: addCard,
                    clearDrawing: clearActiveDrawing,
                    zoomOut: { zoom(by: 0.85, in: proxy) },
                    zoomIn: { zoom(by: 1.15, in: proxy) },
                    fit: { fitWorkspace(in: proxy) },
                    resetZoom: resetView
                )
                .padding(.bottom, 20)
            }
            .simultaneousGesture(drawingModeActive ? nil : zoomGesture(proxy: proxy))
            .onChange(of: workspace?.id) { oldID, newID in
                if let oldID {
                    saveTask?.cancel()
                    DrawingService.save(currentDrawing, for: oldID)
                }
                activeTool = .select
                loadDrawing(for: newID)
            }
            .onReceive(NotificationCenter.default.publisher(for: .localDataReset)) { _ in
                DrawingService.deleteAll()
                currentDrawing = PKDrawing()
                drawingVersion += 1
                activeTool = .select
            }
            .task { loadDrawing(for: workspace?.id) }
        }
        // DotGrid and background color extend behind the home indicator for a seamless canvas edge
        .background(
            ZStack {
                Color.clipCanvasPageBackground
                DotGrid(offset: canvasOffset, scale: canvasScale)
            }
            .ignoresSafeArea()
        )
    }

    // MARK: Drawing

    private func onDrawingChanged(_ newDrawing: PKDrawing) {
        currentDrawing = newDrawing
        drawingVersion &+= 1
        scheduleSave(newDrawing)
    }

    private func scheduleSave(_ drawing: PKDrawing) {
        saveTask?.cancel()
        guard let id = workspace?.id else { return }
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let d = drawing
            let i = id
            DispatchQueue.global(qos: .utility).async { DrawingService.save(d, for: i) }
        }
    }

    private func loadDrawing(for id: UUID?) {
        let loaded = id.map { DrawingService.load(for: $0) } ?? PKDrawing()
        currentDrawing = loaded
        drawingVersion &+= 1
    }

    private func clearActiveDrawing() {
        if let id = workspace?.id { DrawingService.delete(for: id) }
        currentDrawing = PKDrawing()
        drawingVersion &+= 1
        withAnimation(.snappy(duration: 0.15)) { activeTool = .select }
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
                let next = clampedScale(baseScale * value)
                let c = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                canvasOffset = CGSize(
                    width:  c.x - (c.x - baseOffset.width)  * next / baseScale,
                    height: c.y - (c.y - baseOffset.height) * next / baseScale
                )
                canvasScale = next
            }
            .onEnded { _ in baseScale = canvasScale; baseOffset = canvasOffset }
    }

    private func zoom(by factor: CGFloat, in proxy: GeometryProxy) {
        let next = clampedScale(canvasScale * factor)
        let c = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
        let offset = CGSize(
            width:  c.x - (c.x - canvasOffset.width)  * next / canvasScale,
            height: c.y - (c.y - canvasOffset.height) * next / canvasScale
        )
        withAnimation(.snappy(duration: 0.16)) {
            canvasScale = next; baseScale = next
            canvasOffset = offset; baseOffset = offset
        }
    }

    private func fitWorkspace(in proxy: GeometryProxy) {
        guard let cards = workspace?.cards, !cards.isEmpty else { resetView(); return }
        let bounds = cards.reduce(CGRect.null) { r, c in
            r.union(CGRect(x: c.x - c.width / 2, y: c.y - c.height / 2, width: c.width, height: c.height))
        }
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }
        let pad: CGFloat = 96
        let scale = min(max(min((proxy.size.width - pad) / bounds.width,
                               (proxy.size.height - pad) / bounds.height), 0.35), 1.35)
        let offset = CGSize(width:  proxy.size.width  / 2 - bounds.midX * scale,
                            height: proxy.size.height / 2 - bounds.midY * scale)
        withAnimation(.snappy(duration: 0.22)) {
            canvasScale = scale; baseScale = scale
            canvasOffset = offset; baseOffset = offset
        }
    }

    private func resetView() {
        withAnimation(.snappy(duration: 0.18)) {
            canvasOffset = .zero; baseOffset = .zero
            canvasScale = 1; baseScale = 1
        }
    }

    private func canvasPoint(for location: CGPoint) -> CGPoint {
        CGPoint(x: (location.x - canvasOffset.width)  / canvasScale,
                y: (location.y - canvasOffset.height) / canvasScale)
    }

    private func clampedScale(_ s: CGFloat) -> CGFloat { min(max(s, 0.35), 3) }
}

// MARK: - Unified bottom toolbar (fixed width — always the same buttons)

private struct CanvasBottomBar: View {
    @Binding var activeTool: CanvasTool
    let scale: CGFloat
    let hasDrawing: Bool
    let canZoomOut: Bool
    let canZoomIn: Bool
    let paste: () -> Void
    let addCard: () -> Void
    let clearDrawing: () -> Void
    let zoomOut: () -> Void
    let zoomIn: () -> Void
    let fit: () -> Void
    let resetZoom: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Tool selection
            ToolButton(systemImage: "cursorarrow", label: "Select", isActive: activeTool == .select) {
                withAnimation(.snappy(duration: 0.15)) { activeTool = .select }
            }
            ToolButton(systemImage: "pencil.tip", label: "Draw", isActive: activeTool == .draw) {
                withAnimation(.snappy(duration: 0.15)) { activeTool = .draw }
            }

            barDivider

            // Content
            ToolButton(systemImage: "doc.on.clipboard", label: "Paste from clipboard", isActive: false) { paste() }
            ToolButton(systemImage: "note.text.badge.plus", label: "New card", isActive: false) { addCard() }

            barDivider

            // Zoom
            ToolButton(systemImage: "minus.magnifyingglass", label: "Zoom out", isActive: false) { zoomOut() }
                .disabled(!canZoomOut)
                .opacity(canZoomOut ? 1 : 0.4)

            Button(action: resetZoom) {
                Text("\(Int(scale * 100))%")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 38, height: 36)
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .help("Reset zoom to 100%")

            ToolButton(systemImage: "plus.magnifyingglass", label: "Zoom in", isActive: false) { zoomIn() }
                .disabled(!canZoomIn)
                .opacity(canZoomIn ? 1 : 0.4)

            ToolButton(systemImage: "arrow.up.left.and.arrow.down.right", label: "Fit all cards", isActive: false) { fit() }

            barDivider

            // Clear drawing — always present so the bar never changes width
            ToolButton(
                systemImage: "eraser.fill",
                label: hasDrawing ? "Clear drawing" : "No drawing",
                isActive: false,
                tint: hasDrawing ? .red : .primary
            ) { clearDrawing() }
                .disabled(!hasDrawing)
                .opacity(hasDrawing ? 1 : 0.3)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private var barDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }
}

private struct ToolButton: View {
    let systemImage: String
    let label: String
    let isActive: Bool
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isActive ? .white : tint)
                .frame(width: 34, height: 36)
                .background(isActive ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Shared canvas types

@Observable
final class CanvasDragState {
    var selectionOffset: CGSize = .zero
    var isDraggingActive: Bool = false
}

private struct DotGrid: View {
    let offset: CGSize
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing = max(24 * scale, 12)
            let radius  = min(1.2 * scale, 2)
            var x = offset.width.truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }
            while x < size.width + spacing {
                var y = offset.height.truncatingRemainder(dividingBy: spacing)
                if y < 0 { y += spacing }
                while y < size.height + spacing {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                               width: radius * 2, height: radius * 2)),
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
        VStack(spacing: 12) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Paste from the toolbar · drag clips from the sidebar · or tap + to add a card")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

private extension SnippetDragPayload {
    var hasContent: Bool {
        imageData != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
