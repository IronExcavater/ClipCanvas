import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    let mode: CanvasMode
    @Binding var zoomCommand: ZoomCommand?
    @Binding var selectedPlacementIDs: Set<UUID>
    let onCopyClip: (Clip) -> Void

    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Clip> { $0.deletedAt == nil }) private var clips: [Clip]
    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var activeDrag: (id: UUID, offset: CGSize)?
    @State private var activeResize: (id: UUID, start: CGSize)?

    private var placements: [CanvasPlacement] {
        workspace.placements.filter { $0.clip?.deletedAt == nil }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dotGrid(in: geo)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPlacementIDs.removeAll()
                    }
                    .gesture(mode == .pan ? canvasPanGesture : nil)

                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        positionedCard(placement: placement, clip: clip)
                    }
                }

                if placements.isEmpty { EmptyCanvasHint() }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .simultaneousGesture(pinchGesture(in: geo))
            .dropDestination(for: String.self) { ids, location in
                placeDroppedClips(ids, at: location)
            }
            .onChange(of: zoomCommand) { _, command in
                guard let command else { return }
                handleZoom(command, in: geo)
                zoomCommand = nil
            }
        }
    }

    // MARK: - Dot grid

    private func dotGrid(in geo: GeometryProxy) -> some View {
        Canvas { ctx, size in
            let spacing = max(28.0 * canvasScale, 12)
            let radius = min(1.2 * canvasScale, 2)
            var x = canvasOffset.width.truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }
            while x < size.width + spacing {
                var y = canvasOffset.height.truncatingRemainder(dividingBy: spacing)
                if y < 0 { y += spacing }
                while y < size.height + spacing {
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(.secondary.opacity(0.22))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Card positioning

    private func positionedCard(placement: CanvasPlacement, clip: Clip) -> some View {
        let scale = canvasScale
        let offset = canvasOffset
        let screenCenterX = placement.x * scale + offset.width + (placement.width * scale) / 2
        let screenCenterY = placement.y * scale + offset.height + (placement.height * scale) / 2
        let isDragging = activeDrag?.id == placement.id
        let dragOffset = isDragging ? (activeDrag?.offset ?? .zero) : .zero
        let isSelected = selectedPlacementIDs.contains(placement.id)

        return ClipCard(
            clip: clip,
            isSelected: isSelected,
            onTap: {
                selectedPlacementIDs.insert(placement.id)
                onCopyClip(clip)
            },
            onResize: { resizePlacement(placement, translation: $0) },
            onResizeEnded: { activeResize = nil },
            onToggleExpandedSize: { toggleExpandedSize(for: placement) }
        )
        .frame(width: placement.width, height: placement.height)
        .scaleEffect(scale * (isDragging ? 1.05 : 1.0))
        .frame(width: placement.width * scale, height: placement.height * scale)
        .offset(x: dragOffset.width, y: dragOffset.height)
        .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 16 : 0, y: isDragging ? 8 : 0)
        .gesture(cardDragGesture(for: placement))
        .position(x: screenCenterX, y: screenCenterY)
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDragging)
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                canvasOffset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in baseOffset = canvasOffset }
    }

    private func pinchGesture(in geo: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = min(max(baseScale * value, 0.2), 4.0)
                zoom(to: next, in: geo)
            }
            .onEnded { _ in
                baseScale = canvasScale
                baseOffset = canvasOffset
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                activeDrag = (placement.id, value.translation)
            }
            .onEnded { value in
                placement.x += value.translation.width / canvasScale
                placement.y += value.translation.height / canvasScale
                activeDrag = nil
                workspace.updatedAt = Date()
            }
    }

    // MARK: - Zoom

    private func handleZoom(_ command: ZoomCommand, in geo: GeometryProxy) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            switch command {
            case .zoomIn:
                zoom(to: min(canvasScale * 1.2, 4.0), in: geo)
            case .zoomOut:
                zoom(to: max(canvasScale / 1.2, 0.2), in: geo)
            case .fitContent:
                fitContent(in: geo)
            }
            baseScale = canvasScale
            baseOffset = canvasOffset
        }
    }

    private func zoom(to next: CGFloat, in geo: GeometryProxy) {
        let cx = geo.size.width / 2
        let cy = geo.size.height / 2
        canvasOffset = CGSize(
            width: cx - (cx - baseOffset.width) * next / baseScale,
            height: cy - (cy - baseOffset.height) * next / baseScale
        )
        canvasScale = next
    }

    private func fitContent(in geo: GeometryProxy) {
        guard !placements.isEmpty else {
            canvasOffset = .zero
            baseOffset = .zero
            canvasScale = 1
            baseScale = 1
            return
        }

        let minX = placements.map(\.x).min() ?? 0
        let minY = placements.map(\.y).min() ?? 0
        let maxX = placements.map { $0.x + $0.width }.max() ?? 0
        let maxY = placements.map { $0.y + $0.height }.max() ?? 0
        let contentWidth = max(maxX - minX, 1)
        let contentHeight = max(maxY - minY, 1)
        let availableWidth = max(geo.size.width - 80, 1)
        let availableHeight = max(geo.size.height - 180, 1)
        let next = min(max(min(availableWidth / contentWidth, availableHeight / contentHeight), 0.2), 2.5)
        canvasScale = next
        canvasOffset = CGSize(
            width: geo.size.width / 2 - CGFloat(minX + contentWidth / 2) * next,
            height: geo.size.height / 2 - CGFloat(minY + contentHeight / 2) * next
        )
    }

    private func resizePlacement(_ placement: CanvasPlacement, translation: CGSize) {
        if activeResize?.id != placement.id {
            activeResize = (placement.id, CGSize(width: placement.width, height: placement.height))
        }
        guard let start = activeResize?.start else { return }
        placement.width = max(160, min(420, start.width + translation.width / canvasScale))
        placement.height = max(96, min(520, start.height + translation.height / canvasScale))
        workspace.updatedAt = Date()
    }

    private func toggleExpandedSize(for placement: CanvasPlacement) {
        let size = CanvasPlacementSizing.toggledSize(for: placement)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            placement.width = size.width
            placement.height = size.height
        }
        activeResize = nil
        workspace.updatedAt = Date()
    }

    // MARK: - Actions

    private func deletePlacement(_ placement: CanvasPlacement) {
        selectedPlacementIDs.remove(placement.id)
        context.delete(placement)
        workspace.updatedAt = Date()
    }

    private func placeDroppedClips(_ ids: [String], at location: CGPoint) -> Bool {
        var didPlace = false
        for id in ids {
            guard let uuid = UUID(uuidString: id),
                  let clip = clips.first(where: { $0.id == uuid }) else { continue }
            let canvasPoint = CGPoint(
                x: (location.x - canvasOffset.width) / canvasScale,
                y: (location.y - canvasOffset.height) / canvasScale
            )
            let placement = workspace.place(clip: clip, at: canvasPoint)
            selectedPlacementIDs = [placement.id]
            didPlace = true
        }
        return didPlace
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
            Text("Tap Paste to add your first clip")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
