import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    let mode: CanvasMode
    @Binding var zoomCommand: ZoomCommand?
    @Binding var selectedPlacementIDs: Set<UUID>
    @Binding var visibleScale: CGFloat
    let onCopyClip: (Clip) -> Void

    @Environment(\.modelContext) private var context
    @Query private var allClips: [Clip]
    @State private var viewportOrigin: CGPoint = .zero
    @State private var baseViewportOrigin: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var baseScale: CGFloat = 1.0
    @State private var activeDrag: (id: UUID, offset: CGSize)?
    @State private var activeResize: (id: UUID, start: CGSize, translation: CGSize)?
    @State private var zOrder: [UUID: Double] = [:]
    @State private var nextZOrder: Double = 1
    @State private var panStartOrigin: CGPoint?
    @State private var pinchStartScale: CGFloat?
    @State private var pinchAnchorCenter: CGPoint?

    private var placements: [CanvasPlacement] {
        workspace.placements.filter { $0.clip?.deletedAt == nil }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                CanvasDotGrid(
                    viewportOrigin: viewportOrigin,
                    canvasScale: canvasScale,
                    opacity: gridOpacity(viewportSize: geo.size)
                )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPlacementIDs.removeAll()
                    }
                    .gesture(mode == .pan ? canvasPanGesture(in: geo) : nil)

                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        positionedCard(placement: placement, clip: clip, in: geo)
                    }
                }

                if placements.isEmpty {
                    EmptyCanvasHint()
                        .frame(width: 260, height: 150)
                        .scaleEffect(canvasScale)
                        .position(
                            x: (220 - viewportOrigin.x) * canvasScale,
                            y: (220 - viewportOrigin.y) * canvasScale
                        )
                        .allowsHitTesting(false)
                }
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
            .onChange(of: canvasScale) { _, newValue in
                visibleScale = newValue
            }
            .onAppear {
                visibleScale = canvasScale
            }
        }
    }

    // MARK: - Card positioning

    private func positionedCard(placement: CanvasPlacement, clip: Clip, in geo: GeometryProxy) -> some View {
        let scale = canvasScale
        let isDragging = activeDrag?.id == placement.id
        let dragOffset = isDragging ? (activeDrag?.offset ?? .zero) : .zero
        let isSelected = selectedPlacementIDs.contains(placement.id)
        let size = displaySize(for: placement)
        let screenX = (placement.x - viewportOrigin.x) * scale
        let screenY = (placement.y - viewportOrigin.y) * scale

        return ClipCard(
            clip: clip,
            isSelected: isSelected,
            onTap: {
                bringToFront(placement.id)
                if selectedPlacementIDs.contains(placement.id) {
                    selectedPlacementIDs.remove(placement.id)
                } else {
                    selectedPlacementIDs.insert(placement.id)
                }
                onCopyClip(clip)
            },
            onDoubleTap: { toggleExpandedSize(for: placement, in: geo) },
            onResize: { updateResizePreview(for: placement, translation: $0) },
            onResizeEnded: { commitResize(for: placement) },
            onToggleExpandedSize: { toggleExpandedSize(for: placement, in: geo) }
        )
        .frame(width: size.width, height: size.height)
        .scaleEffect(scale * (isDragging ? 1.05 : 1.0), anchor: .topLeading)
        .offset(x: screenX + dragOffset.width, y: screenY + dragOffset.height)
        .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 16 : 0, y: isDragging ? 8 : 0)
        .gesture(cardDragGesture(for: placement))
        .zIndex(zIndex(for: placement, isSelected: isSelected, isDragging: isDragging))
        .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDragging)
    }

    // MARK: - Gestures

    private func canvasPanGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let start = panStartOrigin ?? viewportOrigin
                if panStartOrigin == nil {
                    panStartOrigin = start
                    baseViewportOrigin = start
                }
                let proposed = CGPoint(
                    x: start.x - value.translation.width / canvasScale,
                    y: start.y - value.translation.height / canvasScale
                )
                viewportOrigin = boundedOrigin(proposed, viewportSize: geo.size, rubberBand: true)
            }
            .onEnded { value in
                let start = panStartOrigin ?? baseViewportOrigin
                let throwVector = CGSize(
                    width: (value.predictedEndTranslation.width - value.translation.width) * 0.18,
                    height: (value.predictedEndTranslation.height - value.translation.height) * 0.18
                )
                let proposed = CGPoint(
                    x: start.x - (value.translation.width + throwVector.width) / canvasScale,
                    y: start.y - (value.translation.height + throwVector.height) / canvasScale
                )
                let target = boundedOrigin(proposed, viewportSize: geo.size, rubberBand: false)
                withAnimation(.smooth(duration: 0.22)) {
                    viewportOrigin = target
                }
                baseViewportOrigin = target
                panStartOrigin = nil
            }
    }

    private func pinchGesture(in geo: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let startScale = pinchStartScale ?? canvasScale
                let anchorCenter = pinchAnchorCenter ?? viewportCenter(in: geo)
                if pinchStartScale == nil {
                    pinchStartScale = startScale
                    pinchAnchorCenter = anchorCenter
                }
                let next = min(max(startScale * value, 0.2), 4.0)
                zoom(to: next, around: anchorCenter, in: geo)
            }
            .onEnded { _ in
                baseScale = canvasScale
                let target = boundedOrigin(viewportOrigin, viewportSize: geo.size, rubberBand: false)
                viewportOrigin = target
                baseViewportOrigin = target
                pinchStartScale = nil
                pinchAnchorCenter = nil
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard activeResize?.id != placement.id else { return }
                bringToFront(placement.id)
                activeDrag = (placement.id, value.translation)
            }
            .onEnded { value in
                guard activeResize?.id != placement.id else { return }
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
            case .arrangeAll:
                arrangePlacements(placements, at: viewportCenter(in: geo), fitAfter: true, in: geo)
            case .arrangeSelection:
                let selected = placements.filter { selectedPlacementIDs.contains($0.id) }
                arrangePlacements(selected, at: viewportCenter(in: geo), fitAfter: false, in: geo)
            }
            baseScale = canvasScale
            baseViewportOrigin = viewportOrigin
        }
    }

    private func zoom(to next: CGFloat, in geo: GeometryProxy) {
        zoom(to: next, around: viewportCenter(in: geo), in: geo)
    }

    private func zoom(to next: CGFloat, around center: CGPoint, in geo: GeometryProxy) {
        canvasScale = next
        viewportOrigin = origin(forCenter: center, viewportSize: geo.size)
    }

    private func fitContent(in geo: GeometryProxy) {
        guard !placements.isEmpty else {
            viewportOrigin = .zero
            baseViewportOrigin = .zero
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
        viewportOrigin = CGPoint(
            x: CGFloat(minX + contentWidth / 2) - geo.size.width / (2 * next),
            y: CGFloat(minY + contentHeight / 2) - geo.size.height / (2 * next)
        )
    }

    private func updateResizePreview(for placement: CanvasPlacement, translation: CGSize) {
        let start = activeResize?.id == placement.id
            ? activeResize?.start ?? CGSize(width: placement.width, height: placement.height)
            : CGSize(width: placement.width, height: placement.height)
        activeResize = (placement.id, start, translation)
        bringToFront(placement.id)
    }

    private func commitResize(for placement: CanvasPlacement) {
        let size = displaySize(for: placement)
        placement.width = size.width
        placement.height = size.height
        activeResize = nil
        activeDrag = nil
        workspace.updatedAt = Date()
    }

    private func displaySize(for placement: CanvasPlacement) -> CGSize {
        guard activeResize?.id == placement.id,
              let start = activeResize?.start,
              let translation = activeResize?.translation else {
            return CGSize(width: placement.width, height: placement.height)
        }
        return CanvasPlacementSizing.snappedSize(CGSize(
            width: start.width + translation.width / canvasScale,
            height: start.height + translation.height / canvasScale
        ), for: placement.clip)
    }

    private func toggleExpandedSize(for placement: CanvasPlacement, in geo: GeometryProxy) {
        let width = placement.clip?.type == .image ? geo.size.width / canvasScale : nil
        let size = CanvasPlacementSizing.toggledSize(for: placement, availableScreenWidth: width)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            placement.width = size.width
            placement.height = size.height
        }
        activeResize = nil
        workspace.updatedAt = Date()
    }

    private func viewportCenter(in geo: GeometryProxy) -> CGPoint {
        CGPoint(
            x: viewportOrigin.x + geo.size.width / (2 * canvasScale),
            y: viewportOrigin.y + geo.size.height / (2 * canvasScale)
        )
    }

    private func viewportCenter(for origin: CGPoint, viewportSize: CGSize) -> CGPoint {
        CGPoint(
            x: origin.x + viewportSize.width / (2 * canvasScale),
            y: origin.y + viewportSize.height / (2 * canvasScale)
        )
    }

    private func origin(forCenter center: CGPoint, viewportSize: CGSize) -> CGPoint {
        CGPoint(
            x: center.x - viewportSize.width / (2 * canvasScale),
            y: center.y - viewportSize.height / (2 * canvasScale)
        )
    }

    private func boundedOrigin(_ proposed: CGPoint, viewportSize: CGSize, rubberBand: Bool) -> CGPoint {
        let bounds = canvasRadiusBounds(viewportSize: viewportSize)
        let proposedCenter = viewportCenter(for: proposed, viewportSize: viewportSize)
        let boundedCenter = bounds.bounded(proposedCenter, rubberBand: rubberBand)
        return origin(forCenter: boundedCenter, viewportSize: viewportSize)
    }

    private func canvasRadiusBounds(viewportSize: CGSize) -> CanvasRadiusBounds {
        let fallback = CGRect(x: 120, y: 140, width: 280, height: 180)
        let contentRect = placements.reduce(CGRect.null) { partial, placement in
            partial.union(CGRect(
                x: CGFloat(placement.x),
                y: CGFloat(placement.y),
                width: CGFloat(placement.width),
                height: CGFloat(placement.height)
            ))
        }
        let usable = contentRect.isNull ? fallback : contentRect
        let center = CGPoint(x: usable.midX, y: usable.midY)
        let contentRadius = hypot(usable.width, usable.height) / 2
        let viewportRadius = hypot(viewportSize.width / canvasScale, viewportSize.height / canvasScale) / 2
        let expansion = max(220, viewportRadius * 0.34 + CGFloat(placements.count) * 16 + contentRadius * 0.12)
        return CanvasRadiusBounds(center: center, radius: max(360, contentRadius + expansion))
    }

    private func gridOpacity(viewportSize: CGSize) -> Double {
        let bounds = canvasRadiusBounds(viewportSize: viewportSize)
        let center = viewportCenter(for: viewportOrigin, viewportSize: viewportSize)
        let distance = hypot(center.x - bounds.center.x, center.y - bounds.center.y)
        let progress = min(max((distance / bounds.radius - 0.54) / 0.46, 0), 1)
        return 0.42 - progress * 0.36
    }

    private func arrangePlacements(_ target: [CanvasPlacement], at center: CGPoint, fitAfter: Bool, in geo: GeometryProxy) {
        guard !target.isEmpty else { return }
        let columns = max(1, Int(ceil(sqrt(Double(target.count)))))
        let rows = Int(ceil(Double(target.count) / Double(columns)))
        let spacing: Double = 22
        var columnWidths = Array(repeating: 0.0, count: columns)
        var rowHeights = Array(repeating: 0.0, count: rows)

        for (index, placement) in target.enumerated() {
            let col = index % columns
            let row = index / columns
            columnWidths[col] = max(columnWidths[col], placement.width)
            rowHeights[row] = max(rowHeights[row], placement.height)
        }

        let totalWidth = columnWidths.reduce(0, +) + spacing * Double(max(columns - 1, 0))
        let totalHeight = rowHeights.reduce(0, +) + spacing * Double(max(rows - 1, 0))
        let originX = Double(center.x) - totalWidth / 2
        let originY = Double(center.y) - totalHeight / 2

        for (index, placement) in target.enumerated() {
            let col = index % columns
            let row = index / columns
            placement.x = originX + columnWidths.prefix(col).reduce(0.0, +) + spacing * Double(col)
            placement.y = originY + rowHeights.prefix(row).reduce(0.0, +) + spacing * Double(row)
            bringToFront(placement.id)
        }
        workspace.updatedAt = Date()
        if fitAfter { fitContent(in: geo) }
    }

    private func bringToFront(_ id: UUID) {
        zOrder[id] = nextZOrder
        nextZOrder += 1
    }

    private func zIndex(for placement: CanvasPlacement, isSelected: Bool, isDragging: Bool) -> Double {
        let base = zOrder[placement.id] ?? 0
        if isDragging { return base + 20_000 }
        if isSelected { return base + 10_000 }
        return base
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
                  let clip = allClips.first(where: { $0.id == uuid }) else { continue }
            let canvasPoint = CGPoint(
                x: viewportOrigin.x + location.x / canvasScale,
                y: viewportOrigin.y + location.y / canvasScale
            )
            if clip.deletedAt != nil {
                clip.restore()
            }
            let placement = workspace.place(clip: clip, at: canvasPoint)
            selectedPlacementIDs = [placement.id]
            didPlace = true
        }
        return didPlace
    }
}

private struct CanvasRadiusBounds {
    let center: CGPoint
    let radius: CGFloat

    func bounded(_ point: CGPoint, rubberBand: Bool) -> CGPoint {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = hypot(dx, dy)
        guard distance > radius, distance > 0 else { return point }

        let overflow = distance - radius
        let boundedDistance = rubberBand ? radius + overflow * 0.24 : radius
        return CGPoint(
            x: center.x + dx / distance * boundedDistance,
            y: center.y + dy / distance * boundedDistance
        )
    }
}

private struct CanvasDotGrid: View, Animatable {
    var viewportOrigin: CGPoint
    var canvasScale: CGFloat
    var opacity: Double

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, Double>> {
        get {
            AnimatablePair(
                AnimatablePair(viewportOrigin.x, viewportOrigin.y),
                AnimatablePair(canvasScale, opacity)
            )
        }
        set {
            viewportOrigin = CGPoint(x: newValue.first.first, y: newValue.first.second)
            canvasScale = newValue.second.first
            opacity = newValue.second.second
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let spacing = max(28.0 * canvasScale, 12)
            let radius = min(1.35 * canvasScale, 2.2)
            var x = (-viewportOrigin.x * canvasScale).truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }

            while x < size.width + spacing {
                var y = (-viewportOrigin.y * canvasScale).truncatingRemainder(dividingBy: spacing)
                if y < 0 { y += spacing }

                while y < size.height + spacing {
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(.secondary.opacity(opacity))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .background(Color(uiColor: .systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
