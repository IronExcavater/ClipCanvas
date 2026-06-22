import PencilKit
import PhotosUI
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void
    var prefersInspector = false

    @Environment(\.modelContext) var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) var workspaces: [Workspace]

    @State var mode: CanvasMode = .pan
    @State var feedbackPresenter = FeedbackPresenter()
    @State var zoomCommand: ZoomCommand?
    @State var visibleScale: CGFloat = 1
    @State var visibleViewportCenter: CGPoint = .zero
    @State var selectedObjectIDs: Set<UUID> = []
    @State var visibleObjectIDs: Set<UUID> = []
    @State var editingObjectID: UUID?
    @State var noteTextCommand: NoteTextCommand?
    @State var detailClip: Clip?
    @State var activeAIChat: AIChat?
    @State var tagClips: [Clip]?
    @State var colorObjects: [CanvasObject]?
    @State var isRenaming = false
    @State var renameText = ""
    @State var activeDrawing: PKDrawing = PKDrawing()
    @State var activeDrawTool: CanvasDrawTool = .pen
    @State var drawToolSettings: CanvasDrawTool?
    @State var keyboardHeight: CGFloat = 0
    @State var penColor: PlatformColor = .label
    @State var penWidth: CGFloat = 3
    @State var highlighterColor: PlatformColor = .systemYellow.withAlphaComponent(0.5)
    @State var highlighterWidth: CGFloat = 20
    @State var eraserWidth: CGFloat = 34
    @State private var measuredTopChromeHeight: CGFloat = 60
    @State var lastClipboardFingerprint: String?
    @AppStorage("settings.clipboardMonitoringEnabled") var clipboardMonitoringEnabled = true
    @AppStorage("settings.iCloudClipboardSyncEnabled") var iCloudClipboardSyncEnabled = false
    @AppStorage("settings.includeImagesInShares") var includeImagesInShares = true
    @AppStorage("settings.clipboardPermissionPromptShown") var clipboardPermissionPromptShown = false
    @AppStorage("settings.clipboardAccessEnabled") var clipboardAccessEnabled = false
    @AppStorage("settings.lastSeenICloudClipboardDate") var lastSeenICloudClipboardTimestamp = 0.0
    @State var showClipboardPermissionPrompt = false
    @State var canvasSearch = ""
    @State var isCanvasSearchActive = false
    @State var isImagePickerPresented = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isLoadingPersistedDrawing = false
    @State private var confirmingClearCanvas = false
    @FocusState var renameFocused: Bool
    @FocusState var searchFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            let usesInspector = shouldUseInspector(width: proxy.size.width)

            HStack(spacing: 0) {
                canvasContent(usesInspector: usesInspector)

                if usesInspector {
                    Divider()
                    CanvasInspectorPanel(
                        selectedObjects: selectedInspectorObjects,
                        detailClip: detailClip,
                        activeAIChat: activeAIChat,
                        onCloseDetail: { detailClip = nil },
                        onCloseChat: { activeAIChat = nil },
                        onEdit: editSelectedContent,
                        onDetails: showSelectedDetails,
                        onTags: showSelectedTags,
                        onColor: showSelectedColors,
                        onArrange: { zoomCommand = .arrangeSelection },
                        onAskAI: askAIAboutSelection,
                        onDelete: deleteSelected
                    )
                    .frame(width: inspectorWidth(for: proxy.size.width))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: usesInspector)
        }
    }

    private func canvasContent(usesInspector: Bool) -> some View {
        ZStack {
            CanvasView(
                workspace: workspace,
                mode: mode,
                keyboardHeight: keyboardHeight,
                topBarContentHeight: measuredTopChromeHeight,
                zoomCommand: $zoomCommand,
                selectedObjectIDs: $selectedObjectIDs,
                editingObjectID: $editingObjectID,
                visibleScale: $visibleScale,
                visibleViewportCenter: $visibleViewportCenter,
                visibleObjectIDs: $visibleObjectIDs,
                activeDrawing: $activeDrawing,
                noteTextCommand: $noteTextCommand,
                drawingTool: pencilTool,
                canvasSearch: canvasSearch,
                onDismissSearch: closeCanvasSearch,
                onShowDetails: { object in
                    if let clip = object.clip {
                        detailClip = clip
                    }
                },
                onManageTags: { objects in
                    let clips = objects.compactMap(\.clip)
                    if !clips.isEmpty {
                        tagClips = clips
                    }
                },
                onAskAI: { objects in
                    openAIChat(attaching: objects)
                },
                onRunAIAction: { skill, objects in
                    runAIAction(skill, on: objects)
                }
            )
            .ignoresSafeArea(.container)

            VStack(spacing: 0) {
                topChrome

                Spacer()

                if editingObjectID == nil {
                    HStack {
                        CanvasUndoControls(
                            onUndo: { undoManager?.undo() },
                            onRedo: { undoManager?.redo() }
                        )
                        .padding(.leading, 14)
                        .padding(.bottom, 12)
                        Spacer()
                        CanvasZoomControls(
                            scale: visibleScale,
                            onZoomIn: { zoomCommand = .zoomIn },
                            onZoomOut: { zoomCommand = .zoomOut }
                        )
                        .padding(.trailing, 14)
                        .padding(.bottom, 12)
                    }
                }

                CanvasToolbar(
                    mode: $mode,
                    selectedCount: selectedObjectIDs.count,
                    selectionKind: selectedCanvasKind,
                    isEditing: editingObjectID != nil,
                    onPaste: paste,
                    onCreateNote: createNoteAtViewCenter,
                    onAskAI: openRecentOrNewAIChat,
                    onInsertImage: insertImageFromLibrary,
                    onDetails: showSelectedDetails,
                    onEditContent: editSelectedContent,
                    onManageTags: showSelectedTags,
                    onArrangeSelection: { zoomCommand = .arrangeSelection },
                    onColor: showSelectedColors,
                    onCopyToClipboard: copySelectedToClipboard,
                    onPasteFromClipboard: pasteClipboardIntoSelected,
                    onFormatBold: { noteTextCommand = NoteTextCommand(kind: .bold) },
                    onFormatItalic: { noteTextCommand = NoteTextCommand(kind: .italic) },
                    onFormatUnderline: { noteTextCommand = NoteTextCommand(kind: .underline) },
                    onFormatStrikethrough: { noteTextCommand = NoteTextCommand(kind: .strikethrough) },
                    onFormatHighlight: { noteTextCommand = NoteTextCommand(kind: .highlight($0)) },
                    onFormatList: { noteTextCommand = NoteTextCommand(kind: .list($0)) },
                    onFormatQuote: { noteTextCommand = NoteTextCommand(kind: .quote) },
                    onFormatLink: { noteTextCommand = NoteTextCommand(kind: .link(url: $0, displayText: $1)) },
                    onFormatIndent: { noteTextCommand = NoteTextCommand(kind: .indent) },
                    onFormatOutdent: { noteTextCommand = NoteTextCommand(kind: .outdent) },
                    onFormatBlockStyle: { noteTextCommand = NoteTextCommand(kind: .blockStyle($0)) },
                    onDelete: deleteSelected,
                    activeDrawTool: activeDrawTool,
                    penColor: penColor,
                    highlighterColor: highlighterColor,
                    onCloseMode: closeToolbarMode,
                    onDrawTool: selectDrawTool,
                    onDrawToolSettings: toggleDrawToolSettings
                )
            }
            .ignoresSafeArea(.container, edges: [.top, .horizontal])

            if let tool = drawToolSettings {
                CanvasBottomOverlay(bottomPadding: 82, onDismiss: dismissDrawToolSettings) {
                    CanvasDrawToolSettingsPanel(
                        tool: tool,
                        color: drawColor(for: tool),
                        width: drawWidth(for: tool),
                        onChangeColor: { setDrawColor($0, for: tool) },
                        onChangeWidth: { setDrawWidth($0, for: tool) },
                        onDismiss: { drawToolSettings = nil }
                    )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(7)
            }

            if let clips = tagClips {
                CanvasBottomOverlay(onDismiss: { tagClips = nil }) {
                    CanvasTagPanel(clips: clips, onDismiss: { tagClips = nil })
                }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(8)
            }

            if let objects = colorObjects {
                CanvasBottomOverlay(onDismiss: { colorObjects = nil }) {
                    CanvasColorPanel(objects: objects, onDismiss: { colorObjects = nil })
                }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(9)
            }

            if confirmingClearCanvas {
                AppConfirmationOverlay(
                    title: "Clear this canvas?",
                    message: "This removes every card from the current canvas.",
                    destructiveTitle: "Clear",
                    onConfirm: {
                        clearAll()
                        confirmingClearCanvas = false
                    },
                    onCancel: { confirmingClearCanvas = false }
                )
                .zIndex(30)
            }

        }
        .appFeedbackOverlay(feedbackPresenter, topPadding: 70)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: selectedObjectIDs)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: keyboardHeight)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: editingObjectID)
        .focusedSceneValue(\.canvasCommandActions, canvasCommandActions)
        .onAppear {
            context.undoManager = undoManager
            loadPersistedDrawing()
            prepareClipboardAccessOnLaunch()
            consumePendingCanvasRoute()
        }
        .onChange(of: mode) { _, newMode in
            if newMode != .edit {
                editingObjectID = nil
                tagClips = nil
                colorObjects = nil
            }
            if newMode != .draw { drawToolSettings = nil }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkClipboardOnForeground()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyToCanvasRequested)) { _ in
            paste()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedTextReceived)) { note in
            if let text = note.object as? String { addSharedText(text) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipCanvasRouteRequested)) { note in
            guard let route = note.object as? AppRoute else { return }
            handleCanvasRoute(route)
        }
        .onChange(of: workspace.id) { _, _ in
            loadPersistedDrawing()
            consumePendingCanvasRoute()
        }
        .onChange(of: activeDrawing) { _, drawing in
            persistActiveDrawing(drawing)
        }
        // Tapping the canvas background deselects everything - also exit inline editing
        // so the keyboard dismisses instead of staying up with no selected card.
        .onChange(of: selectedObjectIDs) { _, newIDs in
            if newIDs.isEmpty {
                tagClips = nil
                colorObjects = nil
            }
            if let editing = editingObjectID, !newIDs.contains(editing) {
                editingObjectID = nil
            }
        }
        .onChange(of: editingObjectID) { _, newValue in
            if newValue == nil {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { keyboardHeight = 0 }
            }
        }
        .modifier(CanvasKeyboardHeightModifier(isEditing: editingObjectID != nil, keyboardHeight: $keyboardHeight))
        .photosPicker(
            isPresented: $isImagePickerPresented,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .alert("Use Clipboard Features?", isPresented: $showClipboardPermissionPrompt) {
            Button("Enable Clipboard") {
                enableClipboardAccessFromLaunchPrompt()
            }
            .keyboardShortcut(.defaultAction)
            Button("Not Now", role: .cancel) {
                disableClipboardAccess()
            }
        } message: {
            Text("Paste, copy, history, and clipboard sync need clipboard access. You can turn this on later in Settings.")
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { await importSelectedImage(newItem) }
        }
        .onPreferenceChange(CanvasTopChromeHeightPreferenceKey.self) { height in
            let newHeight = CanvasTopChromeLayout.resolvedHeight(
                measuredHeight: height,
                expectedHeight: topBarContentHeight
            )
            guard abs(newHeight - measuredTopChromeHeight) > 0.5 else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                measuredTopChromeHeight = newHeight
            }
        }
        .sheet(item: detailSheetBinding(usesInspector: usesInspector)) { clip in
            ClipDetailSheet(clip: clip)
        }
        .sheet(item: chatSheetBinding(usesInspector: usesInspector)) { chat in
            AIChatDetailSheet(chat: chat)
        }
    }

    private var selectedInspectorObjects: [CanvasObject] {
        orderedCanvasObjects(matching: selectedObjectIDs)
            .filter(\.isCanvasContent)
    }

    private func shouldUseInspector(width: CGFloat) -> Bool {
        prefersInspector
            && width >= 760
            && (activeAIChat != nil || detailClip != nil || !selectedInspectorObjects.isEmpty)
    }

    private func inspectorWidth(for width: CGFloat) -> CGFloat {
        min(max(340, width * 0.34), 460)
    }

    private func detailSheetBinding(usesInspector: Bool) -> Binding<Clip?> {
        Binding(
            get: { usesInspector ? nil : detailClip },
            set: { detailClip = $0 }
        )
    }

    private func chatSheetBinding(usesInspector: Bool) -> Binding<AIChat?> {
        Binding(
            get: { usesInspector ? nil : activeAIChat },
            set: { activeAIChat = $0 }
        )
    }

    private func dismissDrawToolSettings() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            drawToolSettings = nil
        }
    }

    private func consumePendingCanvasRoute() {
        guard let route = AppRouteService.pendingRoute else { return }
        handleCanvasRoute(route)
    }

    private func handleCanvasRoute(_ route: AppRoute) {
        switch route {
        case .workspace(let id):
            guard workspace.id == id else { return }
            selectedObjectIDs.removeAll()
            editingObjectID = nil
            mode = .pan
            _ = AppRouteService.consumePendingRoute { $0 == route }
        case .object(let id):
            guard workspace.canvasObjects.contains(where: { $0.id == id && $0.deletedAt == nil }) else { return }
            selectedObjectIDs = [id]
            editingObjectID = nil
            mode = .pan
            zoomCommand = .fitContent
            _ = AppRouteService.consumePendingRoute { $0 == route }
        case .clip, .chat:
            break
        }
    }

    private var canvasCommandActions: CanvasCommandActions {
        CanvasCommandActions(
            canEditSelection: selectedObjectIDs.count == 1,
            canDeleteSelection: !selectedObjectIDs.isEmpty,
            canFormatText: editingObjectID != nil,
            createNote: createNoteAtViewCenter,
            paste: paste,
            askAI: openRecentOrNewAIChat,
            search: toggleCanvasSearch,
            zoomIn: { zoomCommand = .zoomIn },
            zoomOut: { zoomCommand = .zoomOut },
            fitContent: { zoomCommand = .fitContent },
            arrangeSelection: { zoomCommand = .arrangeSelection },
            editSelection: editSelectedContent,
            deleteSelection: deleteSelected,
            bold: { noteTextCommand = NoteTextCommand(kind: .bold) },
            italic: { noteTextCommand = NoteTextCommand(kind: .italic) },
            underline: { noteTextCommand = NoteTextCommand(kind: .underline) },
            strikethrough: { noteTextCommand = NoteTextCommand(kind: .strikethrough) },
            bullet: { noteTextCommand = NoteTextCommand(kind: .list(.bullet)) },
            numbered: { noteTextCommand = NoteTextCommand(kind: .list(.numbered)) },
            checklist: { noteTextCommand = NoteTextCommand(kind: .list(.checklist)) },
            highlight: { noteTextCommand = NoteTextCommand(kind: .highlight(.yellow)) }
        )
    }

    var topBarContentHeight: CGFloat {
        CanvasTopChromeLayout.expectedHeight(searchActive: isCanvasSearchActive)
    }

    private var topChrome: some View {
        VStack(spacing: 0) {
            CanvasTopBar(
                isRenaming: $isRenaming,
                renameText: $renameText,
                renameFocused: $renameFocused,
                onToggleSidebar: toggleSidebar,
                onBeginRename: beginRename,
                onCommitRename: commitRename,
                selectedCount: selectedObjectIDs.count,
                visibleCount: visibleObjectIDs.count,
                shareSelectionText: shareSelectionText,
                shareVisibleText: shareVisibleText,
                shareWorkspaceText: shareWorkspaceText,
                shareWorkspaceURL: shareWorkspaceURL,
                shareImageURLs: shareImageURLs,
                onAskAI: askAIAboutCurrentContext,
                onClearAll: { confirmingClearCanvas = true },
                onArrangeAll: { zoomCommand = .arrangeAll },
                onFitContent: { zoomCommand = .fitContent },
                onSearch: toggleCanvasSearch
            )

            if isCanvasSearchActive {
                CanvasSearchPill(
                    search: $canvasSearch,
                    resultCount: canvasSearchResultCount,
                    totalCount: visibleCanvasObjectCount,
                    searchFocused: $searchFocused,
                    onClose: closeCanvasSearch
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: CanvasTopChromeHeightPreferenceKey.self,
                    value: proxy.frame(in: .global).maxY
                )
            }
        }
    }

    var visibleCanvasObjectCount: Int {
        workspace.canvasObjects.filter(\.isCanvasContent).count
    }

    var shareSelectionText: String {
        CanvasShareExporter.cardsText(orderedCanvasObjects(matching: selectedObjectIDs))
    }

    var shareVisibleText: String {
        CanvasShareExporter.cardsText(orderedCanvasObjects(matching: visibleObjectIDs), title: "Visible ClipCanvas Cards")
    }

    var shareWorkspaceText: String {
        CanvasShareExporter.workspaceText(workspace)
    }

    var shareWorkspaceURL: URL? {
        ClipCanvasWorkspaceShare.temporaryShareURL(for: workspace, includeImages: includeImagesInShares)
    }

    var shareImageURLs: [URL] {
        guard includeImagesInShares else { return [] }
        let source = selectedObjectIDs.isEmpty
            ? orderedCanvasObjects(matching: visibleObjectIDs)
            : orderedCanvasObjects(matching: selectedObjectIDs)
        return CanvasShareExporter.imageURLs(for: source)
    }

    var canvasSearchResultCount: Int {
        let query = canvasSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return visibleCanvasObjectCount }
        return workspace.canvasObjects.filter { object in
            object.isCanvasContent
            && canvasObject(object, matchesSearch: query)
        }.count
    }

    private func canvasObject(_ object: CanvasObject, matchesSearch query: String) -> Bool {
        if object.text.lowercased().contains(query) { return true }
        if object.displayText.lowercased().contains(query) { return true }
        if let clip = object.clip {
            if clip.content.lowercased().contains(query) { return true }
            if clip.preview.lowercased().contains(query) { return true }
            if clip.tags.contains(where: { $0.name.lowercased().contains(query) }) { return true }
        }
        return false
    }

    var selectedCanvasKind: CanvasSelectionKind {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        guard !objects.isEmpty else { return .none }
        let kinds = Set(objects.map(canvasSelectionKind(for:)))
        return kinds.count == 1 ? (kinds.first ?? .none) : .mixed
    }
}

private struct CanvasSearchPill: View {
    @Binding var search: String
    let resultCount: Int
    let totalCount: Int
    var searchFocused: FocusState<Bool>.Binding
    let onClose: () -> Void

    private var resultText: String {
        let noun = totalCount == 1 ? "card" : "cards"
        guard !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "\(totalCount) \(noun)"
        }
        return "\(resultCount) of \(totalCount)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search canvas", text: $search)
                .font(.subheadline.weight(.medium))
                .textFieldStyle(.plain)
                .focused(searchFocused)
                .submitLabel(.search)
                .onSubmit { searchFocused.wrappedValue = false }

            HStack(spacing: 4) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 10, weight: .bold))
                Text(resultText)
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.08), in: Capsule())

        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: 430)
        .glassCapsule(interactive: false)
    }
}

private struct CanvasTopChromeHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 60

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct CanvasKeyboardHeightModifier: ViewModifier {
    let isEditing: Bool
    @Binding var keyboardHeight: CGFloat

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
                guard isEditing else { return }
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let screenHeight = UIApplication.shared.connectedScenes
                        .compactMap { ($0 as? UIWindowScene)?.screen.bounds.height }
                        .first ?? frame.maxY
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        keyboardHeight = max(0, screenHeight - frame.minY)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    keyboardHeight = 0
                }
            }
        #else
        content
        #endif
    }
}
