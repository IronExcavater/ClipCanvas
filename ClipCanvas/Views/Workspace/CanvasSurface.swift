import SwiftData
import SwiftUI

struct CanvasSurface: View {
    let workspace: Workspace?
    // @Binding creates a two-way data connection with the parent (WorkspaceView).
    // Changes here propagate up; changes in the parent propagate down.
    @Binding var selectedCardIDs: Set<UUID>
    @Binding var editingCard: WorkspaceCard?
    let runningTransforms: Set<UUID>
    let openChatForCard: (WorkspaceCard) -> Void
    let copyCard: (WorkspaceCard) -> Void
    let deleteCard: (WorkspaceCard) -> Void
    let duplicateCard: (WorkspaceCard) -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void
    let addDroppedContent: (SnippetDragPayload, CGPoint) -> Void

    // Canvas view state — tracks the current pan offset and zoom scale.
    // We keep both a "base" and a "live" value: the live value updates during the gesture
    // and the base is committed when the gesture ends, so the next gesture starts correctly.
    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    // @State on a class — CanvasDragState is @Observable so all selected cards react
    // to selectionOffset changes without passing Bindings to each card individually.
    @State private var dragState = CanvasDragState()
    // When true, pan/zoom gestures are disabled and the PencilKit drawing overlay is active.
    @State private var drawingModeActive = false

    var body: some View {
        // GeometryReader gives us the surface's size so we can compute zoom anchors
        // and card bounds for the fit-to-workspace feature.
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                DotGrid(offset: canvasOffset, scale: canvasScale)
                    // Disable pan when drawing so finger/pencil strokes go to PencilKit instead.
                    .gesture(drawingModeActive ? nil : panGesture)
                    .onTapGesture {
                        if !drawingModeActive { selectedCardIDs.removeAll() }
                    }

                // DrawingTestView is a UIViewRepresentable wrapping PencilKit's PKCanvasView.
                // It sits above the dot grid (zIndex 5) but below cards (zIndex 10+).
                // allowsHitTesting controls whether touches reach this view or pass through.
                DrawingTestView(
                    isActive: drawingModeActive,
                    canvasOffset: canvasOffset,
                    canvasScale: canvasScale,
                    boardSize: CGSize(width: 5000, height: 5000)
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
                            // .position places the view's centre at (card.x, card.y) in canvas coords.
                            .position(x: card.x, y: card.y)
                            // Higher zIndex floats a view above others — selected cards stay on top.
                            .zIndex(selectedCardIDs.contains(card.id) ? 20 : (card.transformRun == nil ? 1 : 2))
                        }
                    }
                    .frame(width: 5000, height: 5000, alignment: .topLeading)
                    .scaleEffect(canvasScale, anchor: .topLeading)  // zoom from the top-left origin
                    .offset(canvasOffset)
                    .zIndex(10)
                }

                // Zoom/reset controls pinned to the bottom-right corner.
                CanvasControlStrip(
                    scale: canvasScale,
                    zoomOut: { zoom(by: 0.85) },
                    zoomIn: { zoom(by: 1.15) },
                    fit: { fitWorkspace(in: proxy) },
                    reset: resetView
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18)
                .zIndex(1000)

                // Draw / Done toggle button pinned to the top-left corner.
                Button {
                    drawingModeActive.toggle()
                } label: {
                    Label(
                        drawingModeActive ? "Done" : "Draw",
                        systemImage: drawingModeActive ? "checkmark.circle.fill" : "pencil.tip"
                    )
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
                .padding(.top, 12)
                .padding(.leading, 12)
                .zIndex(1000)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            // Accept drops of ClipCanvas's own drag type (SnippetDragPayload).
            .dropDestination(for: SnippetDragPayload.self) { items, location in
                guard let payload = items.first, payload.hasContent else { return false }
                addDroppedContent(payload, canvasPoint(for: location))
                return true
            }
            // Also accept plain-text drops from other apps.
            .dropDestination(for: String.self) { items, location in
                guard let text = items.first?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    return false
                }
                addDroppedContent(SnippetDragPayload(text: text, imageData: nil), canvasPoint(for: location))
                return true
            }
            .clipped()  // clip cards that have been panned/zoomed outside the visible frame
            // .simultaneousGesture lets the zoom recogniser run at the same time as the pan
            // gesture on DotGrid — without this, one gesture would steal priority.
            // Disabled when drawing so pinch gestures don't interfere with PencilKit strokes.
            .simultaneousGesture(drawingModeActive ? nil : zoomGesture(proxy: proxy))
        }
        .background(Color.clipCanvasPageBackground)
    }

    private func select(_ card: WorkspaceCard) {
        // Tap a selected card to deselect it; tap an unselected card to add it to the selection.
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    // DragGesture on the background — pans the entire canvas.
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

    // MagnificationGesture is the two-finger pinch-to-zoom recogniser.
    // We zoom around the screen centre so the user's focal point stays fixed.
    private func zoomGesture(proxy: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let nextScale = clampedScale(baseScale * value)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                // Adjust the pan offset so the point under the screen centre stays in place.
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

    private func zoom(by factor: CGFloat) {
        let nextScale = clampedScale(canvasScale * factor)
        withAnimation(.snappy(duration: 0.16)) {
            canvasScale = nextScale
            baseScale = nextScale
        }
    }

    private func fitWorkspace(in proxy: GeometryProxy) {
        guard let cards = workspace?.cards, !cards.isEmpty else {
            resetView()
            return
        }

        // Compute the bounding box of all cards in canvas coordinates.
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
        // Scale to fit the bounding box, clamped between 35% and 135%.
        let nextScale = min(max(min(availableWidth / bounds.width, availableHeight / bounds.height), 0.35), 1.35)
        // Translate so the bounding box centre aligns with the screen centre.
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

    private func canvasPoint(for location: CGPoint) -> CGPoint {
        // Drop locations arrive in screen coordinates. Convert to canvas coordinates
        // by undoing the pan offset and zoom scale that are currently applied.
        CGPoint(
            x: (location.x - canvasOffset.width)  / canvasScale,
            y: (location.y - canvasOffset.height) / canvasScale
        )
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat { min(max(scale, 0.35), 3) }
}

// @Observable makes this class work with SwiftUI's observation system — any view that
// reads selectionOffset will re-render when it changes, without needing @Published.
@Observable
final class CanvasDragState {
    var selectionOffset: CGSize = .zero
}

// DotGrid draws the canvas background using SwiftUI's Canvas — a lower-level, imperative
// 2D drawing API similar to HTML Canvas. Drawing dots manually is more efficient than
// laying out hundreds of small View instances in a grid.
private struct DotGrid: View {
    let offset: CGSize
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing = max(24 * scale, 12)   // dots get closer as you zoom out
            let radius = min(1.2 * scale, 2)    // dots get smaller as you zoom out
            var x = offset.width.truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }          // handle negative offsets (panned left)
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
        // allowsHitTesting(false) makes this view transparent to gestures —
        // taps pass through to the DotGrid beneath it.
        .allowsHitTesting(false)
    }
}

private extension SnippetDragPayload {
    var hasContent: Bool {
        imageData != nil || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
