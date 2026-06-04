import PencilKit
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CanvasContainerView: View {
    let workspace: Workspace
    let onToggleSidebar: () -> Void

    @Environment(\.modelContext) var context
    @Environment(\.undoManager) private var undoManager
    @Environment(\.scenePhase) private var scenePhase
    @Query(
        filter: #Predicate<Workspace> { $0.deletedAt == nil },
        sort: \Workspace.sortIndex
    ) private var workspaces: [Workspace]

    @State var mode: CanvasMode = .pan
    @State var feedback: String?
    @State var feedbackToken = UUID()
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
    @State var clipboardWatcherTask: Task<Void, Never>?
    @State var lastClipboardFingerprint: String?
    @State var canvasSearch = ""
    @State var isCanvasSearchActive = false
    @FocusState var renameFocused: Bool
    @FocusState var searchFocused: Bool

    var body: some View {
        ZStack {
                CanvasView(
                    workspace: workspace,
                    mode: mode,
                    keyboardHeight: keyboardHeight,
                    topBarContentHeight: topBarContentHeight,
                    zoomCommand: $zoomCommand,
                    selectedObjectIDs: $selectedObjectIDs,
                    editingObjectID: $editingObjectID,
                    visibleScale: $visibleScale,
                    visibleViewportCenter: $visibleViewportCenter,
                    visibleObjectIDs: $visibleObjectIDs,
                    activeDrawing: $activeDrawing,
                    noteTextCommand: $noteTextCommand,
                    drawingTool: pencilTool,
                    canvasSearch: canvasSearch
                )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasTopBar(
                    workspaceName: workspace.name,
                    workspaces: workspaces,
                    activeWorkspaceID: workspace.id,
                    isRenaming: $isRenaming,
                    renameText: $renameText,
                    renameFocused: $renameFocused,
                    onToggleSidebar: toggleSidebar,
                    onBeginRename: beginRename,
                    onCommitRename: commitRename,
                    onSelectWorkspace: { WorkspaceActionService.activate($0, among: workspaces) },
                    selectedCount: selectedObjectIDs.count,
                    visibleCount: visibleObjectIDs.count,
                    onAskAI: askAIAboutCurrentContext,
                    onClearAll: clearAll,
                    onArrangeAll: { zoomCommand = .arrangeAll },
                    onFitContent: { zoomCommand = .fitContent },
                    onSearch: toggleCanvasSearch
                )

                if isCanvasSearchActive {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)

                        TextField("Search canvas", text: $canvasSearch)
                            .font(.subheadline.weight(.medium))
                            .textFieldStyle(.plain)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .onSubmit { searchFocused = false }

                        if !canvasSearch.isEmpty {
                            Button { canvasSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Done") { closeCanvasSearch() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background { Rectangle().glassPanel(cornerRadius: 0, shadow: false) }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

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
                    onFormatBold: { noteTextCommand = NoteTextCommand(kind: .bold) },
                    onFormatBullet: { noteTextCommand = NoteTextCommand(kind: .bullet) },
                    onFormatHighlight: { noteTextCommand = NoteTextCommand(kind: .highlight) },
                    onDelete: deleteSelected,
                    activeDrawTool: activeDrawTool,
                    penColor: penColor,
                    highlighterColor: highlighterColor,
                    onCloseMode: closeToolbarMode,
                    onDrawTool: selectDrawTool,
                    onDrawToolSettings: toggleDrawToolSettings
                )
                .padding(.bottom, keyboardHeight > 0 && editingObjectID != nil ? keyboardHeight - 32 : 0)
            }
            .ignoresSafeArea(.container, edges: .bottom)

            if let tool = drawToolSettings {
                VStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
                                drawToolSettings = nil
                            }
                        }
                    CanvasDrawToolSettingsPanel(
                        tool: tool,
                        color: drawColor(for: tool),
                        width: drawWidth(for: tool),
                        onChangeColor: { setDrawColor($0, for: tool) },
                        onChangeWidth: { setDrawWidth($0, for: tool) },
                        onDismiss: { drawToolSettings = nil }
                    )
                    .padding(.bottom, 98)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(7)
                .ignoresSafeArea(.container, edges: .bottom)
            }

            if let clips = tagClips {
                CanvasTagPanel(clips: clips, onDismiss: { tagClips = nil })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(8)
            }

            if let objects = colorObjects {
                CanvasColorPanel(objects: objects, onDismiss: { colorObjects = nil })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(9)
            }

            VStack {
                Spacer().frame(height: 70)
                FeedbackBanner(message: feedback ?? "")
                    .opacity(feedback == nil ? 0 : 1)
                    .offset(y: feedback == nil ? -12 : 0)
                    .scaleEffect(feedback == nil ? 0.96 : 1)
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: feedback)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: selectedObjectIDs)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: keyboardHeight)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: editingObjectID)
        .onAppear {
            context.undoManager = undoManager
            startClipboardListening()
        }
        .onDisappear {
            stopClipboardListening()
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
                startClipboardListening()
            } else {
                stopClipboardListening()
            }
        }
        // Tapping the canvas background deselects everything — also exit inline editing
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
        .sheet(item: $detailClip) { clip in
            ClipDetailSheet(clip: clip)
        }
        .sheet(item: $activeAIChat) { chat in
            AIChatDetailSheet(chat: chat)
        }
        .onChange(of: activeAIChat) { old, new in
            if new == nil, let old, old.messages.isEmpty {
                context.delete(old)
            }
        }
    }

    var topBarContentHeight: CGFloat {
        60 + (isCanvasSearchActive ? 44 : 0)
    }

    var selectedCanvasKind: CanvasSelectionKind {
        let objects = orderedCanvasObjects(matching: selectedObjectIDs)
        guard !objects.isEmpty else { return .none }
        let kinds = Set(objects.map(canvasSelectionKind(for:)))
        return kinds.count == 1 ? (kinds.first ?? .none) : .mixed
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
