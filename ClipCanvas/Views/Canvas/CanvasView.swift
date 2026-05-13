import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    let mode: CanvasMode
    @Binding var zoomCommand: ZoomCommand?
    @Binding var selectedPlacementIDs: Set<UUID>
    @Binding var visibleScale: CGFloat
    @Binding var visibleViewportCenter: CGPoint
    let onCopyClip: (Clip) -> Void

    @Query private var allClips: [Clip]
    @State private var viewportOrigin: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
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
                    boundsRadius: canvasWorldBounds(viewportSize: geo.size).radius
                )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPlacementIDs.removeAll()
                    }
                    .gesture(mode == .pan ? canvasPanGesture(in: geo) : nil)
                    .zIndex(0)

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
                        .zIndex(1)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .simultaneousGesture(pinchGesture(in: geo))
            .dropDestination(for: String.self) { ids, location in
                placeDroppedClips(ids, at: location, in: geo)
            }
            .onChange(of: zoomCommand) { _, command in
                guard let command else { return }
                handleZoom(command, in: geo)
                zoomCommand = nil
            }
            .onChange(of: canvasScale) { _, newValue in
                visibleScale = newValue
                visibleViewportCenter = viewportCenter(in: geo)
            }
            .onChange(of: viewportOrigin) { _, _ in
                visibleViewportCenter = viewportCenter(in: geo)
            }
            .onAppear {
                visibleScale = canvasScale
                visibleViewportCenter = viewportCenter(in: geo)
                clampAllPlacements(in: geo)
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
            showsContent: scale >= 0.34 || isSelected || isDragging,
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
            onResizeEnded: { commitResize(for: placement, in: geo) },
            onToggleExpandedSize: { toggleExpandedSize(for: placement, in: geo) }
        )
        .frame(width: size.width, height: size.height)
        .scaleEffect(scale * (isDragging ? 1.05 : 1.0), anchor: .topLeading)
        .offset(x: screenX + dragOffset.width, y: screenY + dragOffset.height)
        .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 16 : 0, y: isDragging ? 8 : 0)
        .gesture(cardDragGesture(for: placement, in: geo))
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
                }
                let proposed = CGPoint(
                    x: start.x - value.translation.width / canvasScale,
                    y: start.y - value.translation.height / canvasScale
                )
                viewportOrigin = boundedOrigin(proposed, viewportSize: geo.size, rubberBand: true)
            }
            .onEnded { value in
                let start = panStartOrigin ?? viewportOrigin
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
                let target = boundedOrigin(viewportOrigin, viewportSize: geo.size, rubberBand: false)
                viewportOrigin = target
                pinchStartScale = nil
                pinchAnchorCenter = nil
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement, in geo: GeometryProxy) -> some Gesture {
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
                clampPlacement(placement, in: geo)
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
        }
    }

    private func zoom(to next: CGFloat, in geo: GeometryProxy) {
        zoom(to: next, around: viewportCenter(in: geo), in: geo)
    }

    private func zoom(to next: CGFloat, around center: CGPoint, in geo: GeometryProxy) {
        canvasScale = next
        viewportOrigin = boundedOrigin(origin(forCenter: center, viewportSize: geo.size), viewportSize: geo.size, rubberBand: false)
    }

    private func fitContent(in geo: GeometryProxy) {
        guard !placements.isEmpty else {
            viewportOrigin = .zero
            canvasScale = 1
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
        let proposedOrigin = CGPoint(
            x: CGFloat(minX + contentWidth / 2) - geo.size.width / (2 * next),
            y: CGFloat(minY + contentHeight / 2) - geo.size.height / (2 * next)
        )
        viewportOrigin = boundedOrigin(proposedOrigin, viewportSize: geo.size, rubberBand: false)
    }

    private func updateResizePreview(for placement: CanvasPlacement, translation: CGSize) {
        let start = activeResize?.id == placement.id
            ? activeResize?.start ?? CGSize(width: placement.width, height: placement.height)
            : CGSize(width: placement.width, height: placement.height)
        activeResize = (placement.id, start, translation)
        bringToFront(placement.id)
    }

    private func commitResize(for placement: CanvasPlacement, in geo: GeometryProxy) {
        let size = CanvasPlacementSizing.snappedSize(displaySize(for: placement), for: placement.clip)
        placement.width = size.width
        placement.height = size.height
        clampPlacement(placement, in: geo)
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
        return CanvasPlacementSizing.fluidSize(CGSize(
            width: start.width + translation.width / canvasScale,
            height: start.height + translation.height / canvasScale
        ))
    }

    private func toggleExpandedSize(for placement: CanvasPlacement, in geo: GeometryProxy) {
        let width = placement.clip?.type == .image ? geo.size.width / canvasScale : nil
        let size = CanvasPlacementSizing.toggledSize(for: placement, availableScreenWidth: width)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            placement.width = size.width
            placement.height = size.height
            clampPlacement(placement, in: geo)
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
        let bounds = canvasWorldBounds(viewportSize: viewportSize)
        let proposedCenter = viewportCenter(for: proposed, viewportSize: viewportSize)
        let boundedCenter = bounds.bounded(proposedCenter, rubberBand: rubberBand)
        return origin(forCenter: boundedCenter, viewportSize: viewportSize)
    }

    private func canvasWorldBounds(viewportSize: CGSize) -> CanvasRadiusBounds {
        let totalArea = placements.reduce(CGFloat(0)) { partial, placement in
            partial + CGFloat(placement.width * placement.height)
        }
        let largestDiagonal = placements.map { hypot(CGFloat($0.width), CGFloat($0.height)) }.max() ?? 260
        let viewportRadius = hypot(viewportSize.width / canvasScale, viewportSize.height / canvasScale) / 2
        let contentWeight = sqrt(max(totalArea, CanvasPlacementSizing.defaultSize.width * CanvasPlacementSizing.defaultSize.height))
        let radius = max(
            620,
            viewportRadius * 0.52 + contentWeight * 1.05 + largestDiagonal * 0.45 + CGFloat(placements.count) * 18
        )
        return CanvasRadiusBounds(center: .zero, radius: radius)
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
            clampPlacement(placement, in: geo)
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
        if isDragging { return base + 20_010 }
        if isSelected { return base + 10_010 }
        return base + 10
    }

    // MARK: - Actions

    private func placeDroppedClips(_ ids: [String], at location: CGPoint, in geo: GeometryProxy) -> Bool {
        var didPlace = false
        for (index, id) in ids.enumerated() {
            guard let uuid = UUID(uuidString: id),
                  let clip = allClips.first(where: { $0.id == uuid }) else { continue }
            let canvasPoint = CGPoint(
                x: viewportOrigin.x + location.x / canvasScale + CGFloat(index * 26),
                y: viewportOrigin.y + location.y / canvasScale + CGFloat(index * 22)
            )
            if clip.deletedAt != nil {
                clip.restore()
            }
            let placement = workspace.place(clip: clip, at: canvasPoint)
            clampPlacement(placement, in: geo)
            selectedPlacementIDs = [placement.id]
            didPlace = true
        }
        return didPlace
    }

    private func clampPlacement(_ placement: CanvasPlacement, in geo: GeometryProxy?) {
        let viewportSize = geo?.size ?? CGSize(width: 393, height: 852)
        let bounds = canvasWorldBounds(viewportSize: viewportSize)
        let topLeft = CGPoint(x: placement.x, y: placement.y)
        let size = CGSize(width: placement.width, height: placement.height)
        let clamped = bounds.clampedTopLeft(topLeft, size: size)
        placement.x = clamped.x
        placement.y = clamped.y
    }

    private func clampAllPlacements(in geo: GeometryProxy) {
        placements.forEach { clampPlacement($0, in: geo) }
    }
}
