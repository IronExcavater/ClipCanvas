import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    let mode: CanvasMode
    @Binding var selectedIDs: Set<UUID>
    let onCopyClip: (Clip) -> Void
    let onSelectModeEntry: (UUID) -> Void   // called on long-press: enter select mode with this placement ID

    @Environment(\.modelContext) private var context
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    // Tracks drag start position per placement to compute delta correctly
    @State private var cardDragOrigin: (id: UUID, x: Double, y: Double)?

    private var placements: [CanvasPlacement] { workspace.placements }
    private var effectiveScale: CGFloat { canvasScale * pinchScale }
    private var effectiveOffset: CGSize {
        CGSize(width: canvasOffset.width + dragDelta.width,
               height: canvasOffset.height + dragDelta.height)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dotGrid(in: geo)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if mode == .select { selectedIDs.removeAll() }
                    }
                    .gesture(mode != .select ? canvasPanGesture : nil)

                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        positionedCard(placement: placement, clip: clip)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .simultaneousGesture(canvasPinchGesture)
        .onChange(of: mode) { _, newMode in
            if newMode != .select { selectedIDs.removeAll() }
        }
    }

    // MARK: - Dot grid

    private func dotGrid(in geo: GeometryProxy) -> some View {
        Canvas { ctx, size in
            let spacing = 28.0 * effectiveScale
            let ox = effectiveOffset.width.truncatingRemainder(dividingBy: spacing)
            let oy = effectiveOffset.height.truncatingRemainder(dividingBy: spacing)
            var x = ox; while x < size.width + spacing { defer { x += spacing }
                var y = oy; while y < size.height + spacing { defer { y += spacing }
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(.secondary.opacity(0.22))
                    )
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Card positioning

    private func positionedCard(placement: CanvasPlacement, clip: Clip) -> some View {
        let scale = effectiveScale
        let offset = effectiveOffset
        let screenCenterX = placement.x * scale + offset.width + (placement.width * scale) / 2
        let screenCenterY = placement.y * scale + offset.height + (placement.height * scale) / 2
        let isSelected = selectedIDs.contains(placement.id)

        return ClipCard(
            clip: clip,
            isSelected: isSelected,
            isSelectMode: mode == .select,
            onTap: {
                if mode == .select {
                    if isSelected { selectedIDs.remove(placement.id) }
                    else { selectedIDs.insert(placement.id) }
                } else {
                    onCopyClip(clip)
                }
            },
            onLongPress: { onSelectModeEntry(placement.id) },
            onDelete: { deletePlacement(placement) }
        )
        .frame(width: placement.width, height: placement.height)
        .scaleEffect(scale)
        .frame(width: placement.width * scale, height: placement.height * scale)
        .gesture(cardDragGesture(for: placement))
        .position(x: screenCenterX, y: screenCenterY)
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragDelta) { value, state, _ in state = value.translation }
            .onEnded { value in
                canvasOffset.width += value.translation.width
                canvasOffset.height += value.translation.height
            }
    }

    private var canvasPinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in state = value }
            .onEnded { value in
                canvasScale = (canvasScale * value).clamped(to: 0.2...4.0)
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let scale = effectiveScale
                // Capture start position on first change event
                if cardDragOrigin == nil || cardDragOrigin?.id != placement.id {
                    cardDragOrigin = (placement.id, placement.x, placement.y)
                }
                if let origin = cardDragOrigin, origin.id == placement.id {
                    placement.x = origin.x + value.translation.width / scale
                    placement.y = origin.y + value.translation.height / scale
                }
            }
            .onEnded { _ in cardDragOrigin = nil }
    }

    // MARK: - Actions

    private func deletePlacement(_ placement: CanvasPlacement) {
        selectedIDs.remove(placement.id)
        context.delete(placement)
        workspace.updatedAt = Date()
    }
}
