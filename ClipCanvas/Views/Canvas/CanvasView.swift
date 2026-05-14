import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    let mode: CanvasMode
    @Binding var zoomCommand: ZoomCommand?
    @Binding var selectedObjectIDs: Set<UUID>
    @Binding var editingObjectID: UUID?
    @Binding var visibleScale: CGFloat
    @Binding var visibleViewportCenter: CGPoint

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

    private var canvasObjects: [CanvasObject] {
        workspace.canvasObjects
            .filter(\.isVisible)
            .sorted { lhs, rhs in
                let lhsOrder = zOrder[lhs.id] ?? lhs.zIndex
                let rhsOrder = zOrder[rhs.id] ?? rhs.zIndex
                if lhsOrder == rhsOrder { return lhs.createdAt < rhs.createdAt }
                return lhsOrder < rhsOrder
            }
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
                    selectedObjectIDs.removeAll()
                }
                .gesture(mode.allowsCanvasPan ? canvasPanGesture(in: geo) : nil)
                .zIndex(0)

                ForEach(canvasObjects) { object in
                    positionedObject(object, in: geo)
                }

                if canvasObjects.isEmpty {
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
                clampAllObjects(in: geo)
            }
        }
    }

    // MARK: - Object positioning

    @ViewBuilder
    private func positionedObject(_ object: CanvasObject, in geo: GeometryProxy) -> some View {
        if object.kind == .connector, let connector = object.connector {
            ConnectorView(
                connector: connector,
                viewportOrigin: viewportOrigin,
                canvasScale: canvasScale,
                isSelected: selectedObjectIDs.contains(object.id)
            )
            .frame(width: geo.size.width, height: geo.size.height)
            .zIndex(zIndex(for: object, isSelected: selectedObjectIDs.contains(object.id), isDragging: false))
        } else if (object.kind == .clipNote || object.kind == .image), let clip = object.clip {
            positionedClipObject(object, clip: clip, in: geo)
        } else {
            positionedCardObject(object, in: geo)
        }
    }

    private func positionedClipObject(_ object: CanvasObject, clip: Clip, in geo: GeometryProxy) -> some View {
        let isDragging = activeDrag?.id == object.id
        let isSelected = selectedObjectIDs.contains(object.id)
        let size = displaySize(for: object)

        return ClipCard(
            clip: clip,
            isSelected: isSelected,
            showsContent: canvasScale >= 0.34 || isSelected || isDragging,
            onTap: { toggleSelection(for: object) },
            onDoubleTap: { handleDoubleTap(for: object, in: geo) },
            isEditing: editingObjectID == object.id,
            editingText: clip.content,
            onCommitEditing: { commitClipText($0, clip: clip, object: object) },
            onResize: { updateResizePreview(for: object, translation: $0) },
            onResizeEnded: { commitResize(for: object, in: geo) },
            onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
        )
        .modifier(CanvasObjectPositionModifier(
            object: object,
            viewportOrigin: viewportOrigin,
            canvasScale: canvasScale,
            size: size,
            dragOffset: isDragging ? activeDrag?.offset ?? .zero : .zero,
            isDragging: isDragging
        ))
        .gesture(objectDragGesture(for: object, in: geo))
        .zIndex(zIndex(for: object, isSelected: isSelected, isDragging: isDragging))
    }

    private func positionedCardObject(_ object: CanvasObject, in geo: GeometryProxy) -> some View {
        let isDragging = activeDrag?.id == object.id
        let isSelected = selectedObjectIDs.contains(object.id)
        let size = displaySize(for: object)

        return CanvasObjectView(
            object: object,
            isSelected: isSelected,
            showsContent: canvasScale >= 0.34 || isSelected || isDragging,
            onTap: { toggleSelection(for: object) },
            onDoubleTap: { handleDoubleTap(for: object, in: geo) },
            isEditing: editingObjectID == object.id,
            editingText: object.text,
            onCommitEditing: { commitObjectText($0, object: object) },
            onResize: { updateResizePreview(for: object, translation: $0) },
            onResizeEnded: { commitResize(for: object, in: geo) },
            onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
        )
        .modifier(CanvasObjectPositionModifier(
            object: object,
            viewportOrigin: viewportOrigin,
            canvasScale: canvasScale,
            size: size,
            dragOffset: isDragging ? activeDrag?.offset ?? .zero : .zero,
            isDragging: isDragging
        ))
        .gesture(objectDragGesture(for: object, in: geo))
        .zIndex(zIndex(for: object, isSelected: isSelected, isDragging: isDragging))
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
                let next = CanvasScaleSteps.clamp(startScale * value)
                zoom(to: next, around: anchorCenter, in: geo)
            }
            .onEnded { _ in
                zoom(to: CanvasScaleSteps.nearest(canvasScale), in: geo)
                pinchStartScale = nil
                pinchAnchorCenter = nil
            }
    }

    private func objectDragGesture(for object: CanvasObject, in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard activeResize?.id != object.id else { return }
                bringToFront(object.id)
                activeDrag = (object.id, value.translation)
            }
            .onEnded { value in
                guard activeResize?.id != object.id else { return }
                object.x += value.translation.width / canvasScale
                object.y += value.translation.height / canvasScale
                clampObject(object, in: geo)
                object.markUpdated()
                activeDrag = nil
            }
    }

    // MARK: - Zoom

    private func handleZoom(_ command: ZoomCommand, in geo: GeometryProxy) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            switch command {
            case .zoomIn:
                zoom(to: CanvasScaleSteps.nextZoomIn(from: canvasScale), in: geo)
            case .zoomOut:
                zoom(to: CanvasScaleSteps.nextZoomOut(from: canvasScale), in: geo)
            case .fitContent:
                fitContent(in: geo)
            case .arrangeAll:
                arrangeObjects(canvasObjects, at: viewportCenter(in: geo), fitAfter: true, in: geo)
            case .arrangeSelection:
                let selected = canvasObjects.filter { selectedObjectIDs.contains($0.id) }
                arrangeObjects(selected, at: viewportCenter(in: geo), fitAfter: false, in: geo)
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
        guard !canvasObjects.isEmpty else {
            viewportOrigin = .zero
            canvasScale = 1
            return
        }

        let minX = canvasObjects.map(\.x).min() ?? 0
        let minY = canvasObjects.map(\.y).min() ?? 0
        let maxX = canvasObjects.map { $0.x + $0.width }.max() ?? 0
        let maxY = canvasObjects.map { $0.y + $0.height }.max() ?? 0
        let contentWidth = max(maxX - minX, 1)
        let contentHeight = max(maxY - minY, 1)
        let availableWidth = max(geo.size.width - 80, 1)
        let availableHeight = max(geo.size.height - 180, 1)
        let next = CanvasScaleSteps.fitting(min(availableWidth / contentWidth, availableHeight / contentHeight))
        canvasScale = next
        let proposedOrigin = CGPoint(
            x: CGFloat(minX + contentWidth / 2) - geo.size.width / (2 * next),
            y: CGFloat(minY + contentHeight / 2) - geo.size.height / (2 * next)
        )
        viewportOrigin = boundedOrigin(proposedOrigin, viewportSize: geo.size, rubberBand: false)
    }

    private func updateResizePreview(for object: CanvasObject, translation: CGSize) {
        let start = activeResize?.id == object.id
            ? activeResize?.start ?? CGSize(width: object.width, height: object.height)
            : CGSize(width: object.width, height: object.height)
        activeResize = (object.id, start, translation)
        bringToFront(object.id)
    }

    private func commitResize(for object: CanvasObject, in geo: GeometryProxy) {
        let size = CanvasPlacementSizing.snappedSize(displaySize(for: object), for: object.clip)
        object.width = size.width
        object.height = size.height
        clampObject(object, in: geo)
        object.markUpdated()
        activeResize = nil
        activeDrag = nil
    }

    private func displaySize(for object: CanvasObject) -> CGSize {
        guard activeResize?.id == object.id,
              let start = activeResize?.start,
              let translation = activeResize?.translation else {
            return CGSize(width: object.width, height: object.height)
        }
        return CanvasPlacementSizing.fluidSize(CGSize(
            width: start.width + translation.width / canvasScale,
            height: start.height + translation.height / canvasScale
        ))
    }

    private func toggleExpandedSize(for object: CanvasObject, in geo: GeometryProxy) {
        let width = object.clip?.type == .image ? geo.size.width / canvasScale : nil
        let size = CanvasPlacementSizing.toggledSize(for: object, availableScreenWidth: width)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            object.width = size.width
            object.height = size.height
            clampObject(object, in: geo)
        }
        activeResize = nil
        object.markUpdated()
    }

    private func handleDoubleTap(for object: CanvasObject, in geo: GeometryProxy) {
        if mode == .edit, canEditText(object) {
            beginEditing(object)
        } else {
            toggleExpandedSize(for: object, in: geo)
        }
    }

    private func beginEditing(_ object: CanvasObject) {
        guard canEditText(object) else { return }
        selectedObjectIDs = [object.id]
        editingObjectID = object.id
        bringToFront(object.id)
    }

    private func canEditText(_ object: CanvasObject) -> Bool {
        switch object.kind {
        case .stickyNote:
            return true
        case .clipNote:
            return object.clip?.type != .image
        default:
            return false
        }
    }

    private func commitObjectText(_ text: String, object: CanvasObject) {
        guard object.text != text else { return }
        object.text = text
        object.markUpdated()
    }

    private func commitClipText(_ text: String, clip: Clip, object: CanvasObject) {
        guard clip.content != text else { return }
        clip.content = text
        clip.type = Clip.detect(content: text, imageData: clip.imageData)
        clip.sensitivity = ClipClassificationService.detectSensitivity(text)
        clip.updatedAt = Date()
        object.markUpdated()
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
        let totalArea = canvasObjects.reduce(CGFloat(0)) { partial, object in
            partial + CGFloat(object.width * object.height)
        }
        let largestDiagonal = canvasObjects.map { hypot(CGFloat($0.width), CGFloat($0.height)) }.max() ?? 260
        let viewportRadius = hypot(viewportSize.width / canvasScale, viewportSize.height / canvasScale) / 2
        let contentWeight = sqrt(max(totalArea, CanvasPlacementSizing.defaultSize.width * CanvasPlacementSizing.defaultSize.height))
        let radius = max(
            620,
            viewportRadius * 0.52 + contentWeight * 1.05 + largestDiagonal * 0.45 + CGFloat(canvasObjects.count) * 18
        )
        return CanvasRadiusBounds(center: .zero, radius: radius)
    }

    private func arrangeObjects(_ target: [CanvasObject], at center: CGPoint, fitAfter: Bool, in geo: GeometryProxy) {
        guard !target.isEmpty else { return }

        let objectsByID = Dictionary(uniqueKeysWithValues: target.map { ($0.id, $0) })
        let items = target.map {
            CanvasGridLayoutItem(id: $0.id, size: CGSize(width: $0.width, height: $0.height))
        }
        let frames = CanvasGridLayout.centeredFrames(
            for: items,
            columns: CanvasGridLayout.balancedColumnCount(for: target.count),
            center: center
        )

        for frame in frames {
            guard let object = objectsByID[frame.id] else { continue }
            object.x = Double(frame.origin.x)
            object.y = Double(frame.origin.y)
            clampObject(object, in: geo)
            bringToFront(object.id)
            object.markUpdated()
        }

        if fitAfter { fitContent(in: geo) }
    }

    private func toggleSelection(for object: CanvasObject) {
        bringToFront(object.id)
        if selectedObjectIDs.contains(object.id) {
            selectedObjectIDs.remove(object.id)
        } else {
            selectedObjectIDs.insert(object.id)
        }
    }

    private func bringToFront(_ id: UUID) {
        zOrder[id] = nextZOrder
        nextZOrder += 1
    }

    private func zIndex(for object: CanvasObject, isSelected: Bool, isDragging: Bool) -> Double {
        let base = zOrder[object.id] ?? object.zIndex
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
            if let object = workspace.canvasObjects.first(where: { $0.sourcePlacementID == placement.id }) {
                clampObject(object, in: geo)
                selectedObjectIDs = [object.id]
            }
            didPlace = true
        }
        return didPlace
    }

    private func clampObject(_ object: CanvasObject, in geo: GeometryProxy?) {
        let viewportSize = geo?.size ?? CGSize(width: 393, height: 852)
        let bounds = canvasWorldBounds(viewportSize: viewportSize)
        let topLeft = CGPoint(x: object.x, y: object.y)
        let size = CGSize(width: object.width, height: object.height)
        let clamped = bounds.clampedTopLeft(topLeft, size: size)
        object.x = clamped.x
        object.y = clamped.y
    }

    private func clampAllObjects(in geo: GeometryProxy) {
        canvasObjects.forEach { clampObject($0, in: geo) }
    }
}

private struct CanvasObjectPositionModifier: ViewModifier {
    let object: CanvasObject
    let viewportOrigin: CGPoint
    let canvasScale: CGFloat
    let size: CGSize
    let dragOffset: CGSize
    let isDragging: Bool

    func body(content: Content) -> some View {
        content
            .frame(width: size.width, height: size.height)
            .scaleEffect(canvasScale * (isDragging ? 1.05 : 1.0), anchor: .topLeading)
            .offset(
                x: (object.x - viewportOrigin.x) * canvasScale + dragOffset.width,
                y: (object.y - viewportOrigin.y) * canvasScale + dragOffset.height
            )
            .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 16 : 0, y: isDragging ? 8 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDragging)
    }
}
