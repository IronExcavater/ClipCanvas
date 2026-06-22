import PencilKit
import SwiftUI
import SwiftData

struct CanvasView: View {
    @Environment(\.modelContext) private var context

    let workspace: Workspace
    let mode: CanvasMode
    let keyboardHeight: CGFloat
    let topBarContentHeight: CGFloat
    @Binding var zoomCommand: ZoomCommand?
    @Binding var selectedObjectIDs: Set<UUID>
    @Binding var editingObjectID: UUID?
    @Binding var visibleScale: CGFloat
    @Binding var visibleViewportCenter: CGPoint
    @Binding var visibleObjectIDs: Set<UUID>
    @Binding var activeDrawing: PKDrawing
    @Binding var noteTextCommand: NoteTextCommand?
    var drawingTool: PKTool
    var canvasSearch: String = ""
    var onDismissSearch: () -> Void = {}
    var onShowDetails: (CanvasObject) -> Void = { _ in }
    var onManageTags: ([CanvasObject]) -> Void = { _ in }
    var onAskAI: ([CanvasObject]) -> Void = { _ in }
    var onRunAIAction: (AITransformSkill, [CanvasObject]) -> Void = { _, _ in }
    var onWillMutateCanvas: () -> Void = {}

    private let drawingWorldOrigin = CGPoint(x: 10_000, y: 10_000)
    private let drawingWorldSize = CGSize(width: 20_000, height: 20_000)

    @Query private var allClips: [Clip]
    @State private var viewportOrigin: CGPoint = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var activeDrag: CanvasDragSession?
    @State private var activeResize: CanvasResizeSession?
    @State private var zOrder: [UUID: Double] = [:]
    @State private var nextZOrder: Double = 1
    @State private var panStartOrigin: CGPoint?
    @State private var pinchStartScale: CGFloat?
    @State private var pinchAnchorCenter: CGPoint?
    @State private var isPanningCanvas = false
    @State private var isPinchingCanvas = false
    @State private var didInitializeViewport = false
    @State private var editOverlayContentHeight: CGFloat = 0

    private var canvasObjects: [CanvasObject] {
        workspace.canvasObjects
            .filter(\.isCanvasContent)
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
                .simultaneousGesture(mode.allowsCanvasPan && editingObjectID == nil ? canvasPanGesture(in: geo) : nil)
                .zIndex(0)

                if !canvasSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(0.64)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .zIndex(0.5)
                        .transition(.opacity)
                }

                CanvasDrawingLayer(
                    drawing: $activeDrawing,
                    activeTool: drawingTool,
                    viewportOrigin: viewportOrigin,
                    canvasScale: canvasScale,
                    worldOrigin: drawingWorldOrigin,
                    worldSize: drawingWorldSize
                )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(mode == .draw)
                    .zIndex(1)

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

                if let selectedID = editingObjectID,
                   let selectedObject = canvasObjects.first(where: { $0.id == selectedID }) {
                    editModeOverlay(for: selectedObject, in: geo)
                        .zIndex(20000)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .simultaneousGesture(editingObjectID == nil ? pinchGesture(in: geo) : nil)
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
        if object.kind == .image || object.clip?.type == .image, let clip = object.clip {
            canvasPlacement(for: object, in: geo) { isSelected, isDragging in
                CanvasImageObjectView(
                    clip: clip,
                    isSelected: isSelected,
                    showsContent: true,
                    onTap: { handleTap(for: object, in: geo) },
                    onDoubleTap: { handleDoubleTap(for: object, in: geo) },
                    onResize: { updateResizePreview(for: object, translation: $0) },
                    onResizeEnded: { commitResize(for: object, in: geo) },
                    onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
                )
            }
        } else if object.kind == .clipNote, let clip = object.clip {
            canvasPlacement(for: object, in: geo) { isSelected, isDragging in
                ClipCard(
                    clip: clip,
                    fillColor: Color(hex: object.style.fillHex),
                    isTransparentSurface: object.style.hasTransparentFill,
                    isSelected: isSelected,
                    showsContent: canvasScale >= 0.34 || isSelected || isDragging,
                    onTap: { handleTap(for: object, in: geo) },
                    onDoubleTap: { handleDoubleTap(for: object, in: geo) },
                    isEditing: false,
                    editingText: clip.content,
                    fontSize: CanvasPlacementSizing.fontSizeForContent(clip.content, width: object.width),
                    textCommand: nil,
                    onCommitEditing: { _ in },
                    onExitEditing: {},
                    onEditorSizeChange: { _ in },
                    onResize: { updateResizePreview(for: object, translation: $0) },
                    onResizeEnded: { commitResize(for: object, in: geo) },
                    onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
                )
            }
        } else {
            canvasPlacement(for: object, in: geo) { isSelected, isDragging in
                CanvasObjectView(
                    object: object,
                    isSelected: isSelected,
                    showsContent: canvasScale >= 0.34 || isSelected || isDragging,
                    onTap: { handleTap(for: object, in: geo) },
                    onDoubleTap: { handleDoubleTap(for: object, in: geo) },
                    isEditing: false,
                    editingText: object.text,
                    textCommand: nil,
                    onCommitEditing: { _ in },
                    onExitEditing: {},
                    onEditorSizeChange: { _ in },
                    onResize: { updateResizePreview(for: object, translation: $0) },
                    onResizeEnded: { commitResize(for: object, in: geo) },
                    onToggleExpandedSize: { toggleExpandedSize(for: object, in: geo) }
                )
            }
        }
    }

    /// Applies the shared canvas positioning + interaction modifiers to any object view.
    private func canvasPlacement<Content: View>(
        for object: CanvasObject,
        in geo: GeometryProxy,
        @ViewBuilder content: (Bool, Bool) -> Content  // (isSelected, isDragging)
    ) -> some View {
        let isDragging = activeDrag?.objectIDs.contains(object.id) == true
        let isSelected = selectedObjectIDs.contains(object.id)
        let isOverlaid = editingObjectID == object.id
        return content(isSelected, isDragging)
            .modifier(CanvasObjectPositionModifier(
                object: object,
                viewportOrigin: viewportOrigin,
                canvasScale: canvasScale,
                size: displaySize(for: object),
                dragOffset: isDragging ? activeDrag?.translation ?? .zero : .zero,
                isDragging: isDragging
            ))
            .opacity(isOverlaid ? 0 : searchOpacity(for: object))
            .allowsHitTesting(!isOverlaid)
            .simultaneousGesture(objectDragGesture(for: object, in: geo))
            .modifier(CanvasContextMenuPreviewShapeModifier())
            .contextMenu {
                objectContextMenu(for: object, in: geo)
            } preview: {
                objectContextPreview(for: object)
            }
            .zIndex(zIndex(for: object, isSelected: isSelected, isDragging: isDragging))
            .transaction { transaction in
                if isDragging || activeResize?.objectID == object.id {
                    transaction.animation = nil
                }
            }
    }

    @ViewBuilder
    private func objectContextMenu(for object: CanvasObject, in geo: GeometryProxy) -> some View {
        if canEditText(object) {
            Button("Edit Text", systemImage: "character.cursor.ibeam") {
                beginEditing(object, in: geo)
            }
        }

        if object.clip != nil || canEditText(object) {
            Button("Info", systemImage: "info.circle") {
                let target = clipBackedObjectForActions(object)
                selectObjectForMenu(target)
                onShowDetails(target)
            }

            Button("Tags", systemImage: "tag") {
                let target = clipBackedObjectForActions(object)
                selectObjectForMenu(target)
                onManageTags([target])
            }
        }

        Button("Ask AI", systemImage: "sparkles") {
            selectObjectForMenu(object)
            onAskAI([object])
        }

        Button("Delete", systemImage: "trash", role: .destructive) {
            selectObjectForMenu(object)
            delete(object)
        }
    }

    @ViewBuilder
    private func objectContextPreview(for object: CanvasObject) -> some View {
        let size = contextPreviewSize(for: object)
        if object.kind == .image || object.clip?.type == .image, let clip = object.clip {
            CanvasImageObjectView(
                clip: clip,
                isSelected: true,
                showsContent: true,
                onTap: {},
                onDoubleTap: {},
                onResize: { _ in },
                onResizeEnded: {},
                onToggleExpandedSize: {}
            )
            .frame(width: size.width, height: size.height)
            .modifier(CanvasObjectContextPreviewChrome())
            .allowsHitTesting(false)
        } else if object.kind == .clipNote, let clip = object.clip {
            ClipCard(
                clip: clip,
                fillColor: Color(hex: object.style.fillHex),
                isTransparentSurface: false,
                isSelected: true,
                showsContent: true,
                onTap: {},
                onDoubleTap: {},
                isEditing: false,
                editingText: clip.content,
                fontSize: CanvasPlacementSizing.fontSizeForContent(clip.content, width: object.width),
                textCommand: nil,
                onCommitEditing: { _ in },
                onExitEditing: {},
                onEditorSizeChange: { _ in },
                onResize: { _ in },
                onResizeEnded: {},
                onToggleExpandedSize: {}
            )
            .frame(width: size.width, height: size.height)
            .modifier(CanvasObjectContextPreviewChrome())
            .allowsHitTesting(false)
        } else {
            CanvasObjectView(
                object: object,
                isSelected: true,
                showsContent: true,
                onTap: {},
                onDoubleTap: {},
                isEditing: false,
                editingText: object.text,
                textCommand: nil,
                onCommitEditing: { _ in },
                onExitEditing: {},
                onEditorSizeChange: { _ in },
                onResize: { _ in },
                onResizeEnded: {},
                onToggleExpandedSize: {}
            )
            .frame(width: size.width, height: size.height)
            .modifier(CanvasObjectContextPreviewChrome())
            .allowsHitTesting(false)
        }
    }

    private func contextPreviewSize(for object: CanvasObject) -> CGSize {
        let source = displaySize(for: object)
        let maxWidth: CGFloat = 280
        let maxHeight: CGFloat = 220
        let scale = min(maxWidth / max(source.width, 1), maxHeight / max(source.height, 1), 1)
        return CGSize(
            width: max(120, source.width * scale),
            height: max(86, source.height * scale)
        )
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

    private func matchesSearch(_ object: CanvasObject) -> Bool {
        let query = canvasSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        if object.text.lowercased().contains(query) { return true }
        if object.displayText.lowercased().contains(query) { return true }
        if let clip = object.clip {
            if clip.content.lowercased().contains(query) { return true }
            if clip.preview.lowercased().contains(query) { return true }
            if clip.tags.contains(where: { $0.name.lowercased().contains(query) }) { return true }
        }
        return false
    }

    private func searchOpacity(for object: CanvasObject) -> CGFloat {
        guard !canvasSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 1 }
        return matchesSearch(object) ? 1 : 0.12
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
                    onDismissSearch()
                    editingObjectID = nil
                    selectedObjectIDs.removeAll()
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
                isPanningCanvas = true
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
                isPanningCanvas = false
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
                isPinchingCanvas = true
                let next = CanvasScaleSteps.clamp(startScale * value)
                zoom(to: next, around: anchorCenter, in: geo)
            }
            .onEnded { _ in
                isPinchingCanvas = false
                withAnimation(.smooth(duration: 0.18)) {
                    zoom(to: CanvasScaleSteps.nearest(canvasScale), in: geo)
                }
                pinchStartScale = nil
                pinchAnchorCenter = nil
            }
    }

    private func objectDragGesture(for object: CanvasObject, in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard activeResize?.objectID != object.id else { return }
                guard editingObjectID == nil else { return }
                let ids = dragObjectIDs(startingFrom: object)
                if activeDrag?.objectIDs != ids {
                    ids.forEach(bringToFront)
                }
                withTransaction(Transaction(animation: nil)) {
                    activeDrag = CanvasDragSession(anchorID: object.id, objectIDs: ids, translation: value.translation)
                }
            }
            .onEnded { value in
                guard activeResize?.objectID != object.id else { return }
                guard editingObjectID == nil else { return }
                let session = activeDrag
                let ids = session?.objectIDs ?? dragObjectIDs(startingFrom: object)
                let committedTranslation = value.translation
                guard committedTranslation != .zero else {
                    withTransaction(Transaction(animation: nil)) {
                        activeDrag = nil
                    }
                    return
                }
                onWillMutateCanvas()
                for movedObject in canvasObjects where ids.contains(movedObject.id) {
                    movedObject.x += committedTranslation.width / canvasScale
                    movedObject.y += committedTranslation.height / canvasScale
                    clampObject(movedObject, in: geo)
                    movedObject.markUpdated()
                }
                withTransaction(Transaction(animation: nil)) {
                    activeDrag = nil
                }
                updateVisibleObjectIDs(in: geo)
            }
    }

    // MARK: - Zoom

    private func handleZoom(_ command: ZoomCommand, in geo: GeometryProxy) {
        withAnimation(.smooth(duration: 0.22)) {
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

        fit(frames: canvasObjects.map(\.frame), in: geo)
    }

    private func fit(frames: [CGRect], in geo: GeometryProxy) {
        guard let union = frames.reduce(nil, { partial, frame in
            partial?.union(frame) ?? frame
        }) else { return }

        let contentWidth = max(union.width, 1)
        let contentHeight = max(union.height, 1)
        let availableWidth = max(geo.size.width - 80, 1)
        let availableHeight = max(geo.size.height - 180, 1)
        let next = CanvasScaleSteps.fitting(min(availableWidth / contentWidth, availableHeight / contentHeight))
        canvasScale = next
        let bounds = canvasBounds(viewportSize: geo.size)
        viewportOrigin = CanvasViewportFitting.origin(
            centeredOn: union,
            viewportSize: geo.size,
            scale: next,
            bounds: bounds
        )
    }

    private func updateResizePreview(for object: CanvasObject, translation: CGSize) {
        guard editingObjectID == nil else { return }
        let start = activeResize?.objectID == object.id
            ? activeResize?.startSize ?? CGSize(width: object.width, height: object.height)
            : CGSize(width: object.width, height: object.height)
        withTransaction(Transaction(animation: nil)) {
            activeResize = CanvasResizeSession(objectID: object.id, startSize: start, translation: translation)
        }
        bringToFront(object.id)
    }

    private func commitResize(for object: CanvasObject, in geo: GeometryProxy) {
        guard editingObjectID == nil else { return }
        guard let session = activeResize, session.objectID == object.id else { return }
        let size = CanvasPlacementSizing.committedSize(for: session, scale: canvasScale, clip: object.clip)
        guard abs(object.width - size.width) > 0.5 || abs(object.height - size.height) > 0.5 else {
            withTransaction(Transaction(animation: nil)) {
                activeResize = nil
                activeDrag = nil
            }
            return
        }
        onWillMutateCanvas()
        object.width = size.width
        object.height = size.height
        clampObject(object, in: geo)
        withTransaction(Transaction(animation: nil)) {
            activeResize = nil
            activeDrag = nil
        }
        object.markUpdated()
    }

    private func displaySize(for object: CanvasObject) -> CGSize {
        guard let session = activeResize, session.objectID == object.id else {
            let size = CGSize(width: object.width, height: object.height)
            if object.clip?.type == .image {
                return CanvasPlacementSizing.snappedSize(size, for: object.clip, snapsToGrid: false)
            }
            return size
        }
        return CanvasPlacementSizing.previewSize(for: session, scale: canvasScale, clip: object.clip)
    }

    private func toggleExpandedSize(for object: CanvasObject, in geo: GeometryProxy) {
        let width = geo.size.width / canvasScale
        let size = CanvasPlacementSizing.toggledSize(for: object, availableScreenWidth: width)
        onWillMutateCanvas()
        let bounds = canvasBounds(viewportSize: geo.size)
        let frame = CanvasViewportFitting.frame(
            expanding: object.frame,
            to: size,
            bounds: bounds
        )
        let origin = CanvasViewportFitting.origin(
            centeredOn: frame,
            viewportSize: geo.size,
            scale: canvasScale,
            bounds: bounds
        )

        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
            object.frame = frame
            viewportOrigin = origin
        }
        activeResize = nil
        object.markUpdated()
    }

    private func handleDoubleTap(for object: CanvasObject, in geo: GeometryProxy) {
        if mode == .edit, canEditText(object) {
            if editingObjectID == object.id { return }
            selectedObjectIDs = [object.id]
            beginEditing(object, in: geo)
        } else {
            toggleExpandedSize(for: object, in: geo)
        }
    }

    private func beginEditing(_ object: CanvasObject, in geo: GeometryProxy) {
        guard canEditText(object) else { return }
        selectedObjectIDs = [object.id]
        editingObjectID = object.id
        bringToFront(object.id)
    }

    private func handleEditingChange(from oldValue: UUID?, to newValue: UUID?, in geo: GeometryProxy) {
        if let id = newValue {
            selectedObjectIDs = [id]
        } else {
            editOverlayContentHeight = 0
        }
    }


    private func canEditText(_ object: CanvasObject) -> Bool {
        switch object.kind {
        case .stickyNote, .text:
            return true
        case .clipNote:
            return object.clip?.type != .image
        default:
            return false
        }
    }

    private func isImageObject(_ object: CanvasObject) -> Bool {
        object.kind == .image || object.clip?.type == .image
    }

    private func canRunAIActions(on object: CanvasObject) -> Bool {
        if object.clip?.type == .image { return false }
        return object.clip != nil || canEditText(object)
    }

    private func imageAspectRatio(for object: CanvasObject) -> CGFloat? {
        guard let data = object.clip?.imageData,
              let image = PlatformImage(data: data),
              image.size.height > 0 else {
            return nil
        }
        return image.size.width / image.size.height
    }

    // MARK: - Edit Mode Overlay

    private func editScreenFrame(in geo: GeometryProxy) -> CGRect {
        CanvasEditOverlayLayout.availableFrame(
            viewportSize: geo.size,
            topBarContentHeight: topBarContentHeight,
            keyboardHeight: keyboardHeight,
            safeAreaBottom: geo.safeAreaInsets.bottom
        )
    }

    private func updateEditOverlayContentHeight(_ contentSize: CGSize, maxHeight: CGFloat) {
        let newHeight = (contentSize.height + CanvasPlacementSizing.contentChrome.height + 16)
            .clamped(to: 80...maxHeight)
        guard abs(newHeight - editOverlayContentHeight) > 0.5 else { return }
        editOverlayContentHeight = newHeight
    }

    @ViewBuilder
    private func editModeOverlay(for object: CanvasObject, in geo: GeometryProxy) -> some View {
        let available = editScreenFrame(in: geo)

        if canEditText(object) {
            let content = object.clip?.content ?? object.text
            let estimatedLines = CGFloat(CanvasPlacementSizing.textLineCount(for: content, width: available.width))
            let estimatedHeight = CanvasPlacementSizing.contentChrome.height
                + estimatedLines * CanvasPlacementSizing.lineHeight + 16
            let naturalHeight = min(max(estimatedHeight, 80), available.height)
            let height: CGFloat = editOverlayContentHeight > 0
                ? min(editOverlayContentHeight, available.height)
                : naturalHeight

            Group {
                if let clip = object.clip {
                    ClipCard(
                        clip: clip,
                        fillColor: Color(hex: object.style.fillHex),
                        isTransparentSurface: object.style.hasTransparentFill,
                        isSelected: true,
                        showsContent: true,
                        onTap: { if editingObjectID != object.id { beginEditing(object, in: geo) } },
                        onDoubleTap: {},
                        isEditing: editingObjectID == object.id,
                        editingText: clip.content,
                        fontSize: 15,
                        textCommand: noteTextCommand,
                        onCommitEditing: { commitClipText($0, clip: clip, object: object) },
                        onExitEditing: { editingObjectID = nil },
                        onEditorSizeChange: { updateEditOverlayContentHeight($0, maxHeight: available.height) },
                        onResize: { _ in },
                        onResizeEnded: {},
                        onToggleExpandedSize: {}
                    )
                } else {
                    CanvasObjectView(
                        object: object,
                        isSelected: true,
                        showsContent: true,
                        onTap: { if editingObjectID != object.id { beginEditing(object, in: geo) } },
                        onDoubleTap: {},
                        isEditing: editingObjectID == object.id,
                        editingText: object.text,
                        textCommand: noteTextCommand,
                        onCommitEditing: { commitObjectText($0, object: object) },
                        onExitEditing: { editingObjectID = nil },
                        onEditorSizeChange: { updateEditOverlayContentHeight($0, maxHeight: available.height) },
                        onResize: { _ in },
                        onResizeEnded: {},
                        onToggleExpandedSize: {}
                    )
                }
            }
            .frame(width: available.width, height: height)
            .offset(x: available.minX, y: available.minY)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: height)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: available)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: topBarContentHeight)
        } else if isImageObject(object), let clip = object.clip {
            let aspect = imageAspectRatio(for: object) ?? max(object.width / max(object.height, 1), 1)
            let rawImgHeight = available.width / max(aspect, 0.001)
            let imgHeight = min(rawImgHeight, available.height)
            let imgWidth: CGFloat = imgHeight < rawImgHeight ? imgHeight * aspect : available.width
            let xOffset = available.minX + (available.width - imgWidth) / 2
            let yOffset = available.minY + (available.height - imgHeight) / 2

            CanvasImageObjectView(
                clip: clip,
                isSelected: true,
                showsContent: true,
                onTap: { selectedObjectIDs.removeAll() },
                onDoubleTap: {},
                onResize: { _ in },
                onResizeEnded: {},
                onToggleExpandedSize: {}
            )
            .frame(width: imgWidth, height: imgHeight)
            .offset(x: xOffset, y: yOffset)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: available)
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: topBarContentHeight)
        }
    }

    private func commitObjectText(_ text: String, object: CanvasObject) {
        guard object.text != text else { return }
        onWillMutateCanvas()
        object.text = text
        object.markUpdated()
    }

    private func commitClipText(_ text: String, clip: Clip, object: CanvasObject) {
        guard clip.content != text else { return }
        onWillMutateCanvas()
        let classification = ClipClassificationService.classifySensitivity(text)
        clip.content = text
        clip.updateDetectedType()
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
            columns: CanvasGridLayout.compactColumnCount(for: items),
            center: center
        )

        var didCaptureSnapshot = false
        for frame in frames {
            guard let object = objectsByID[frame.id] else { continue }
            if !didCaptureSnapshot {
                onWillMutateCanvas()
                didCaptureSnapshot = true
            }
            object.x = Double(frame.origin.x)
            object.y = Double(frame.origin.y)
            clampObject(object, in: geo)
            bringToFront(object.id)
            object.markUpdated()
        }

        let arrangedFrames = frames.map { CGRect(origin: $0.origin, size: $0.size) }
        if fitAfter {
            fitContent(in: geo)
        } else {
            fit(frames: arrangedFrames, in: geo)
        }
        updateVisibleObjectIDs(in: geo)
    }

    private func handleTap(for object: CanvasObject, in geo: GeometryProxy) {
        onDismissSearch()
        bringToFront(object.id)
        if selectedObjectIDs.contains(object.id) {
            selectedObjectIDs.remove(object.id)
        } else {
            selectedObjectIDs.insert(object.id)
        }
    }

    private func selectObjectForMenu(_ object: CanvasObject) {
        selectedObjectIDs = [object.id]
        bringToFront(object.id)
    }

    private func clipBackedObjectForActions(_ object: CanvasObject) -> CanvasObject {
        guard object.clip == nil, canEditText(object) else { return object }
        onWillMutateCanvas()
        let clip = Clip(content: object.text, origin: .typed)
        context.insert(clip)
        object.clip = clip
        object.kind = .clipNote
        object.text = ""
        object.markUpdated()
        return object
    }

    private func dragObjectIDs(startingFrom object: CanvasObject) -> Set<UUID> {
        selectedObjectIDs.contains(object.id) ? selectedObjectIDs : [object.id]
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
        onWillMutateCanvas()
        let note = workspace.createNote(centeredAt: center, size: CanvasPlacementSizing.defaultSize)
        clampObject(note, in: geo)
        selectedObjectIDs = [note.id]
        bringToFront(note.id)
        if shouldBeginEditing {
            beginEditing(note, in: geo)
        }
    }

    private func duplicate(_ object: CanvasObject, in geo: GeometryProxy) {
        onWillMutateCanvas()
        let copiedClip = object.clip?.duplicateForCanvas()
        if let copiedClip {
            context.insert(copiedClip)
        }

        let copy = CanvasObject(
            kind: object.kind,
            workspace: workspace,
            clip: copiedClip,
            x: object.x + 28,
            y: object.y + 28,
            width: object.width,
            height: object.height,
            text: object.text,
            shapeKind: object.shapeKind,
            style: object.style,
            connector: object.connector
        )
        copy.rotation = object.rotation
        copy.groupID = object.groupID
        copy.drawingData = object.drawingData
        copy.zIndex = nextZOrder
        nextZOrder += 1
        context.insert(copy)
        workspace.canvasObjects.append(copy)
        clampObject(copy, in: geo)
        selectedObjectIDs = [copy.id]
        updateVisibleObjectIDs(in: geo)
    }

    private func delete(_ object: CanvasObject) {
        onWillMutateCanvas()
        context.delete(object)
        selectedObjectIDs.remove(object.id)
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
            if !didPlace {
                onWillMutateCanvas()
            }
            let object = workspace.placeDuplicate(of: clip, at: canvasPoint, in: context)
            clampObject(object, in: geo)
            selectedObjectIDs = [object.id]
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

private struct CanvasDragSession {
    let anchorID: UUID
    let objectIDs: Set<UUID>
    let translation: CGSize
}

private struct CanvasContextMenuPreviewShapeModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content.contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        #else
        content.contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 14, style: .continuous))
        #endif
    }
}

private struct CanvasObjectContextPreviewChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
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
            .scaleEffect(canvasScale, anchor: .topLeading)
            .offset(
                x: (object.x - viewportOrigin.x) * canvasScale + dragOffset.width,
                y: (object.y - viewportOrigin.y) * canvasScale + dragOffset.height
            )
            .shadow(color: .black.opacity(isDragging ? 0.22 : 0), radius: isDragging ? 16 : 0, y: isDragging ? 8 : 0)
    }
}
