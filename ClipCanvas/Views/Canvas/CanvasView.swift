import PencilKit
import SwiftUI
import SwiftData

struct CanvasView: View {
    @Environment(\.modelContext) private var context

    let workspace: Workspace
    let mode: CanvasMode
    @Binding var zoomCommand: ZoomCommand?
    @Binding var selectedObjectIDs: Set<UUID>
    @Binding var editingObjectID: UUID?
    @Binding var visibleScale: CGFloat
    @Binding var visibleViewportCenter: CGPoint
    @Binding var visibleObjectIDs: Set<UUID>
    @Binding var activeDrawing: PKDrawing
    var drawingTool: PKTool

    @Query private var allClips: [Clip]
    @State private var viewportOrigin: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var activeDrag: CanvasDragSession?
    @State private var activeResize: CanvasResizeSession?
    @State private var editingSnapshot: EditingFrameSnapshot?
    @State private var zOrder: [UUID: Double] = [:]
    @State private var nextZOrder: Double = 1
    @State private var panStartOrigin: CGPoint?
    @State private var pinchStartScale: CGFloat?
    @State private var pinchAnchorCenter: CGPoint?
    @State private var didInitializeViewport = false

    private var canvasObjects: [CanvasObject] {
        workspace.canvasObjects
            .filter { $0.isVisible && $0.kind != .connector }
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
                    boundsRadius: canvasBounds(viewportSize: geo.size).radius
                )
                .contentShape(Rectangle())
                .gesture(canvasTapGesture(in: geo))
                .simultaneousGesture(mode.allowsCanvasPan ? canvasPanGesture(in: geo) : nil)
                .zIndex(0)

                if mode == .draw {
                    CanvasDrawingLayer(drawing: $activeDrawing, activeTool: drawingTool)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(true)
                        .zIndex(1)
                }

                ForEach(renderedCanvasObjects(in: geo)) { object in
                    positionedObject(object, in: geo)
                }

                if canvasObjects.isEmpty {
                    EmptyCanvasHint()
                        .frame(width: 260, height: 150)
                        .scaleEffect(canvasScale.clamped(to: 0.85...1.15))
                        .position(originScreenPoint(in: geo))
                        .allowsHitTesting(false)
                        .zIndex(2)
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
                DispatchQueue.main.async {
                    zoomCommand = nil
                }
            }
            .onChange(of: canvasScale) { _, newValue in
                visibleScale = newValue
                visibleViewportCenter = viewportCenter(in: geo)
                updateVisibleObjectIDs(in: geo)
            }
            .onChange(of: viewportOrigin) { _, _ in
                visibleViewportCenter = viewportCenter(in: geo)
                updateVisibleObjectIDs(in: geo)
            }
            .onChange(of: editingObjectID) { oldValue, newValue in
                handleEditingChange(from: oldValue, to: newValue, in: geo)
            }
            .onChange(of: canvasObjects.count) { _, _ in
                updateVisibleObjectIDs(in: geo)
            }
            .onAppear {
                initializeViewport(in: geo)
            }
        }
    }

    // MARK: - Object positioning

    @ViewBuilder
    private func positionedObject(_ object: CanvasObject, in geo: GeometryProxy) -> some View {
        if (object.kind == .clipNote || object.kind == .image), let clip = object.clip {
            positionedClipObject(object, clip: clip, in: geo)
        } else {
            positionedCardObject(object, in: geo)
        }
    }

    private func renderedCanvasObjects(in geo: GeometryProxy) -> [CanvasObject] {
        guard !canvasObjects.isEmpty else { return [] }
        let viewport = viewportRect(in: geo).insetBy(dx: -240, dy: -240)
        return canvasObjects.filter { object in
            selectedObjectIDs.contains(object.id)
            || editingObjectID == object.id
            || activeDrag?.objectIDs.contains(object.id) == true
            || activeResize?.objectID == object.id
            || viewport.intersects(object.frame)
        }
    }

    private func positionedClipObject(_ object: CanvasObject, clip: Clip, in geo: GeometryProxy) -> some View {
        let isDragging = activeDrag?.objectIDs.contains(object.id) == true
        let isSelected = selectedObjectIDs.contains(object.id)
        let size = displaySize(for: object)

        return ClipCard(
            clip: clip,
            fillColor: Color(hex: object.style.fillHex),
            isSelected: isSelected,
            showsContent: canvasScale >= 0.34 || isSelected || isDragging,
            onTap: { handleTap(for: object, in: geo) },
            onDoubleTap: { handleDoubleTap(for: object, in: geo) },
            isEditing: editingObjectID == object.id,
            editingText: clip.content,
            onCommitEditing: { commitClipText($0, clip: clip, object: object) },
            onExitEditing: { editingObjectID = nil },
            onEditorSizeChange: { _ in },
            onResize: { updateResizePreview(for: object, translation: $0) },
            onResizeEnded: { commitResize(for: object, in: geo) },
            onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
        )
        .modifier(CanvasObjectPositionModifier(
            object: object,
            viewportOrigin: viewportOrigin,
            canvasScale: canvasScale,
            size: size,
            dragOffset: isDragging ? activeDrag?.translation ?? .zero : .zero,
            isDragging: isDragging
        ))
        .gesture(objectDragGesture(for: object, in: geo))
        .zIndex(zIndex(for: object, isSelected: isSelected, isDragging: isDragging))
    }

    private func positionedCardObject(_ object: CanvasObject, in geo: GeometryProxy) -> some View {
        let isDragging = activeDrag?.objectIDs.contains(object.id) == true
        let isSelected = selectedObjectIDs.contains(object.id)
        let size = displaySize(for: object)

        return CanvasObjectView(
            object: object,
            isSelected: isSelected,
            showsContent: canvasScale >= 0.34 || isSelected || isDragging,
            onTap: { handleTap(for: object, in: geo) },
            onDoubleTap: { handleDoubleTap(for: object, in: geo) },
            isEditing: editingObjectID == object.id,
            editingText: object.text,
            onCommitEditing: { commitObjectText($0, object: object) },
            onExitEditing: { editingObjectID = nil },
            onEditorSizeChange: { _ in },
            onResize: { updateResizePreview(for: object, translation: $0) },
            onResizeEnded: { commitResize(for: object, in: geo) },
            onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
        )
        .modifier(CanvasObjectPositionModifier(
            object: object,
            viewportOrigin: viewportOrigin,
            canvasScale: canvasScale,
            size: size,
            dragOffset: isDragging ? activeDrag?.translation ?? .zero : .zero,
            isDragging: isDragging
        ))
        .gesture(objectDragGesture(for: object, in: geo))
        .zIndex(zIndex(for: object, isSelected: isSelected, isDragging: isDragging))
    }

    // MARK: - Gestures

    private func canvasTapGesture(in geo: GeometryProxy) -> some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first:
                    guard mode == .edit else { return }
                    createNote(at: viewportCenter(in: geo), in: geo, beginEditing: true)
                case .second:
                    if editingObjectID != nil {
                        editingObjectID = nil
                    } else {
                        selectedObjectIDs.removeAll()
                    }
                }
            }
    }

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
                guard activeResize?.objectID != object.id else { return }
                let ids = dragObjectIDs(startingFrom: object)
                ids.forEach(bringToFront)
                activeDrag = CanvasDragSession(anchorID: object.id, objectIDs: ids, translation: value.translation)
            }
            .onEnded { value in
                guard activeResize?.objectID != object.id else { return }
                let ids = activeDrag?.objectIDs ?? dragObjectIDs(startingFrom: object)
                for movedObject in canvasObjects where ids.contains(movedObject.id) {
                    movedObject.x += value.translation.width / canvasScale
                    movedObject.y += value.translation.height / canvasScale
                    clampObject(movedObject, in: geo)
                    movedObject.markUpdated()
                }
                activeDrag = nil
                updateVisibleObjectIDs(in: geo)
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
        let start = activeResize?.objectID == object.id
            ? activeResize?.startSize ?? CGSize(width: object.width, height: object.height)
            : CGSize(width: object.width, height: object.height)
        activeResize = CanvasResizeSession(objectID: object.id, startSize: start, translation: translation)
        bringToFront(object.id)
    }

    private func commitResize(for object: CanvasObject, in geo: GeometryProxy) {
        guard let session = activeResize, session.objectID == object.id else { return }
        let size = CanvasPlacementSizing.committedSize(for: session, scale: canvasScale, clip: object.clip)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
            object.width = size.width
            object.height = size.height
            clampObject(object, in: geo)
            activeResize = nil
            activeDrag = nil
        }
        object.markUpdated()
    }

    private func displaySize(for object: CanvasObject) -> CGSize {
        guard let session = activeResize, session.objectID == object.id else {
            return CGSize(width: object.width, height: object.height)
        }
        return CanvasPlacementSizing.previewSize(for: session, scale: canvasScale)
    }

    private func toggleExpandedSize(for object: CanvasObject, in geo: GeometryProxy) {
        let width = geo.size.width / canvasScale
        let size = CanvasPlacementSizing.toggledSize(for: object, availableScreenWidth: width)
        let bounds = canvasBounds(viewportSize: geo.size)
        let frame = CanvasViewportFitting.frame(
            expanding: object.frame,
            to: size,
            bounds: bounds
        )
        let origin = CanvasViewportFitting.origin(
            revealing: frame,
            currentOrigin: viewportOrigin,
            viewportSize: geo.size,
            scale: canvasScale,
            bounds: bounds
        )

        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            object.frame = frame
            viewportOrigin = origin
            clampObject(object, in: geo)
        }
        activeResize = nil
        object.markUpdated()
    }

    private func handleDoubleTap(for object: CanvasObject, in geo: GeometryProxy) {
        if mode == .edit, canEditText(object) {
            beginEditing(object, in: geo)
        } else {
            toggleExpandedSize(for: object, in: geo)
        }
    }

    private func beginEditing(_ object: CanvasObject, in geo: GeometryProxy) {
        guard canEditText(object) else { return }
        selectedObjectIDs = [object.id]
        prepareEditingFrame(for: object, in: geo)
        editingObjectID = object.id
        bringToFront(object.id)
    }

    private func handleEditingChange(from oldValue: UUID?, to newValue: UUID?, in geo: GeometryProxy) {
        if let oldValue, oldValue != newValue {
            restoreEditingFrame(for: oldValue, in: geo)
        }

        guard let newValue else {
            restoreEditingFrame(for: nil, in: geo)
            return
        }

        guard editingSnapshot?.id != newValue,
              let object = canvasObjects.first(where: { $0.id == newValue }),
              canEditText(object) else { return }
        selectedObjectIDs = [newValue]
        prepareEditingFrame(for: object, in: geo)
    }

    private func prepareEditingFrame(for object: CanvasObject, in geo: GeometryProxy) {
        if editingSnapshot?.id != object.id {
            editingSnapshot = EditingFrameSnapshot(id: object.id, frame: object.frame)
        }

        let targetSize = CanvasPlacementSizing.editingSize(
            for: object,
            viewportSize: geo.size,
            scale: canvasScale
        )
        let targetFrame = CanvasPlacementSizing.frameForEditing(
            object.frame,
            targetSize: targetSize,
            viewport: viewportRect(in: geo)
        )

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            object.frame = targetFrame
            clampObject(object, in: geo)
        }
    }

    private func restoreEditingFrame(for id: UUID?, in geo: GeometryProxy) {
        guard let snapshot = editingSnapshot,
              id == nil || snapshot.id == id,
              let object = workspace.canvasObjects.first(where: { $0.id == snapshot.id }) else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            object.frame = snapshot.frame
            clampObject(object, in: geo)
        }
        editingSnapshot = nil
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
        let classification = ClipClassificationService.classifySensitivity(text)
        clip.content = text
        clip.type = Clip.detect(content: text, imageData: clip.imageData)
        clip.updateSensitivity(classification.sensitivity, reason: classification.reason)
        clip.updatedAt = Date()
        object.markUpdated()
    }

    private func viewportCenter(in geo: GeometryProxy) -> CGPoint {
        CanvasViewportBounds.viewportCenter(
            origin: viewportOrigin,
            viewportSize: geo.size,
            scale: canvasScale
        )
    }

    private func origin(forCenter center: CGPoint, viewportSize: CGSize) -> CGPoint {
        CanvasViewportBounds.origin(
            forCenter: center,
            viewportSize: viewportSize,
            scale: canvasScale
        )
    }

    private func originScreenPoint(in geo: GeometryProxy) -> CGPoint {
        CGPoint(
            x: -viewportOrigin.x * canvasScale,
            y: -viewportOrigin.y * canvasScale
        )
    }

    private func boundedOrigin(_ proposed: CGPoint, viewportSize: CGSize, rubberBand: Bool) -> CGPoint {
        CanvasViewportBounds.boundedOrigin(
            proposed,
            viewportSize: viewportSize,
            scale: canvasScale,
            bounds: canvasBounds(viewportSize: viewportSize),
            rubberBand: rubberBand
        )
    }

    private func canvasBounds(viewportSize: CGSize) -> CanvasRadiusBounds {
        CanvasViewportBounds.radius(
            forObjectSizes: canvasObjects.map { CGSize(width: $0.width, height: $0.height) },
            viewportSize: viewportSize,
            scale: canvasScale
        )
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
        updateVisibleObjectIDs(in: geo)
    }

    private func handleTap(for object: CanvasObject, in geo: GeometryProxy) {
        bringToFront(object.id)
        if mode == .edit, canEditText(object) {
            selectedObjectIDs = [object.id]
            if editingSnapshot?.id == object.id {
                editingObjectID = object.id
            } else {
                prepareEditingFrame(for: object, in: geo)
            }
        } else {
            if selectedObjectIDs.contains(object.id) {
                selectedObjectIDs.remove(object.id)
            } else {
                selectedObjectIDs.insert(object.id)
            }
        }
    }

    private func dragObjectIDs(startingFrom object: CanvasObject) -> Set<UUID> {
        selectedObjectIDs.contains(object.id) ? selectedObjectIDs : [object.id]
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

    private func createNote(at center: CGPoint, in geo: GeometryProxy, beginEditing shouldBeginEditing: Bool) {
        let note = workspace.createNote(centeredAt: center, size: CanvasPlacementSizing.defaultSize)
        context.insert(note)
        clampObject(note, in: geo)
        selectedObjectIDs = [note.id]
        bringToFront(note.id)
        if shouldBeginEditing {
            beginEditing(note, in: geo)
        }
    }

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
        let viewportSize = geo?.size ?? CanvasViewportBounds.defaultViewportSize
        let bounds = canvasBounds(viewportSize: viewportSize)
        let topLeft = CGPoint(x: object.x, y: object.y)
        let size = CGSize(width: object.width, height: object.height)
        let clamped = bounds.clampedTopLeft(topLeft, size: size)
        object.x = clamped.x
        object.y = clamped.y
    }

    private func clampAllObjects(in geo: GeometryProxy) {
        canvasObjects.forEach { clampObject($0, in: geo) }
    }

    private func updateVisibleObjectIDs(in geo: GeometryProxy) {
        let viewport = viewportRect(in: geo).insetBy(dx: -80, dy: -80)
        let ids = Set(canvasObjects.filter { viewport.intersects($0.frame) }.map(\.id))
        guard ids != visibleObjectIDs else { return }
        DispatchQueue.main.async {
            if visibleObjectIDs != ids {
                visibleObjectIDs = ids
            }
        }
    }

    private func viewportRect(in geo: GeometryProxy) -> CGRect {
        CGRect(
            x: viewportOrigin.x,
            y: viewportOrigin.y,
            width: geo.size.width / canvasScale,
            height: geo.size.height / canvasScale
        )
    }

    private func initializeViewport(in geo: GeometryProxy) {
        guard !didInitializeViewport else { return }
        didInitializeViewport = true
        viewportOrigin = CanvasViewportFitting.initialOrigin(
            viewportSize: geo.size,
            scale: canvasScale
        )
        visibleScale = canvasScale
        visibleViewportCenter = viewportCenter(in: geo)
        updateVisibleObjectIDs(in: geo)
        clampAllObjects(in: geo)
    }
}

private struct EditingFrameSnapshot {
    let id: UUID
    let frame: CGRect
}

private struct CanvasDragSession {
    let anchorID: UUID
    let objectIDs: Set<UUID>
    let translation: CGSize
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
