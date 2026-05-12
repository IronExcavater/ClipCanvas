import SwiftData
import SwiftUI

struct WorkspaceView: View {
    // @Environment injects dependencies provided by a parent view — here the SwiftData
    // write context and the observable router live up in ClipCanvasApp.
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass  // compact = iPhone portrait

    // @Query subscribes to the SwiftData store and re-renders this view whenever
    // the matching rows change — like a reactive database subscription.
    @Query(
        filter: #Predicate<Workspace> { !$0.isArchived },
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]

    // @State is local view state — SwiftUI re-renders the view whenever any @State value changes.
    @State private var selectedCardIDs = Set<UUID>()
    @State private var editingCard: WorkspaceCard?
    @State private var showChatPanel = false
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showChatHistory = false
    @State private var feedback: String?
    @State private var runningTransforms = Set<UUID>()
    @State private var droppedChatContext: [String] = []
    @State private var lastObservedClipboard: String?
    @State private var showSidebar = false

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var selectedCards: [WorkspaceCard] {
        guard let workspace = activeWorkspace else { return [] }
        return workspace.cards.filter { selectedCardIDs.contains($0.id) }
    }

    private var chatContextCards: [WorkspaceCard] { selectedCards }

    var body: some View {
        mainContent
            // .sheet presents a modal card — `item:` variant automatically dismisses when item becomes nil.
            .sheet(item: $editingCard) { card in
                CardEditSheet(card: card)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
            .sheet(isPresented: $showChatHistory) {
                ChatHistoryView()
            }
            // .onChange fires whenever the observed value changes, giving both old and new values.
            .onChange(of: router.pendingRoute) { _, route in
                consumePendingRoute(route)
            }
            // .task runs an async closure tied to this view's lifetime — automatically
            // cancelled when the view disappears, unlike DispatchQueue or .onAppear.
            .task {
                AppBootstrap.ensureActiveWorkspace(in: modelContext)
                consumePendingRoute(router.pendingRoute)
            }
            // .task(id:) restarts the async task whenever the id value changes.
            // Switching workspaces cancels the old clipboard listener and starts a new one.
            .task(id: activeWorkspace?.id) {
                await listenForClipboardChanges()
            }
            .animation(.snappy(duration: 0.18), value: showChatPanel)
            .animation(.spring(duration: 0.25), value: feedback)
    }

    // MARK: Layout

    @ViewBuilder
    private var mainContent: some View {
        // GeometryReader gives access to the available size at runtime — useful for
        // responsive layouts that can't be expressed with purely declarative constraints.
        GeometryReader { proxy in
            let isVertical = sizeClass == .compact || proxy.size.width < 760 || proxy.size.height > proxy.size.width * 1.25
            if isVertical {
                // On narrow screens the sidebar slides in as an overlay drawer.
                ZStack(alignment: .leading) {
                    canvasContent(toggleSidebar: { withAnimation { showSidebar.toggle() } }, isNarrow: true)
                    if showSidebar {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation { showSidebar = false } }
                        sidebar
                            .transition(.move(edge: .leading))  // slides in from the left edge
                    }
                }
                .animation(.spring(duration: 0.25), value: showSidebar)
            } else {
                // On wide screens the sidebar is always visible as a fixed left panel.
                HStack(spacing: 0) {
                    sidebar
                    Divider()
                    canvasContent(toggleSidebar: nil, isNarrow: false)
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        WorkspaceSidebar(
            workspaces: workspaces,
            snippets: Array(snippets.prefix(60)),
            activeWorkspace: activeWorkspace,
            selectedCount: selectedCardIDs.count,
            activateWorkspace: { activateWorkspace($0.id) },
            createWorkspace: createWorkspace,
            renameWorkspace: renameWorkspace,
            deleteWorkspace: deleteWorkspace,
            addSnippetToCanvas: addSnippetToCanvas,
            copySnippet: copySnippet,
            openHistory: { showHistory = true },
            openSettings: { showSettings = true },
            openChat: { showChatHistory = true }
        )
        .frame(width: 252)
    }

    private var canvasSurface: some View {
        CanvasSurface(
            workspace: activeWorkspace,
            selectedCardIDs: $selectedCardIDs,
            editingCard: $editingCard,
            runningTransforms: runningTransforms,
            openChatForCard: openChat(for:),
            copyCard: copyCard,
            deleteCard: deleteCard,
            duplicateCard: duplicateCard,
            moveCards: moveCards,
            addDroppedContent: addDroppedContent,
            paste: { pasteToCanvas(method: .manualPaste) },
            addCard: addBlankCard
        )
    }

    @ViewBuilder
    private func chatPanel(isNarrow: Bool) -> some View {
        if showChatPanel, let workspace = activeWorkspace {
            Divider()
            WorkspaceChatPanel(
                workspace: workspace,
                contextCards: chatContextCards,
                extraContext: $droppedChatContext,
                insertReply: insertChatReply,
                close: { showChatPanel = false }
            )
            .frame(width: isNarrow ? nil : 360)
            .frame(maxHeight: isNarrow ? 330 : nil)
            .background(.regularMaterial)   // frosted glass material that adapts to light/dark mode
        }
    }

    @ViewBuilder
    private func canvasContent(toggleSidebar: (() -> Void)?, isNarrow: Bool) -> some View {
        VStack(spacing: 0) {
            WorkspaceTopBar(
                workspace: activeWorkspace,
                isChatVisible: showChatPanel,
                toggleChat: { showChatPanel.toggle() },
                openHistory: { showHistory = true },
                openSettings: { showSettings = true },
                toggleSidebar: toggleSidebar
            )

            Divider()

            ZStack(alignment: .top) {
                if isNarrow {
                    VStack(spacing: 0) {
                        canvasSurface
                        chatPanel(isNarrow: true)
                    }
                } else {
                    HStack(spacing: 0) {
                        canvasSurface
                        chatPanel(isNarrow: false)
                    }
                }

                VStack(spacing: 6) {
                    if selectedCardIDs.count > 0 {
                        selectionBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if let feedback {
                        Text(feedback)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 10)
                .animation(.snappy(duration: 0.2), value: selectedCardIDs.count > 0)
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 2) {
            // Count badge
            HStack(spacing: 5) {
                Text("\(selectedCardIDs.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.accentColor, in: Circle())
                Text(selectedCardIDs.count == 1 ? "selected" : "selected")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
            .padding(.trailing, 6)

            selectionDivider

            selectionIconButton("sparkles", help: "Ask AI") { openChatForSelection() }
            selectionIconButton("doc.on.doc", help: "Copy") { copySelectedCards() }

            Menu {
                ForEach(TransformKind.allCases, id: \.self) { kind in
                    Button(kind.label) { runTransform(kind) }
                }
            } label: {
                Image(systemName: "wand.and.sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 34, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .help("Apple Intelligence transforms")

            selectionDivider

            selectionIconButton("trash", help: "Delete", tint: .red) { deleteSelectedCards() }

            Menu {
                Button(
                    selectedArePrivate ? "Unmark Private" : "Mark Private",
                    systemImage: selectedArePrivate ? "lock.open" : "lock",
                    action: toggleSelectedPrivacy
                )
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .frame(height: 40)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
    }

    private func selectionIconButton(_ icon: String, help label: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
    }

    private var selectionDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 3)
    }

    // MARK: Routing

    private func consumePendingRoute(_ route: AppRoute?) {
        switch route {
        case .workspace(let id):
            activateWorkspace(id)
            router.pendingRoute = nil
        case .copyToCanvas:
            pasteToCanvas(method: router.pendingPasteMethod ?? .quickAction)
            router.pendingRoute = nil
            router.pendingPasteMethod = nil
        case .library:
            showHistory = true
            router.pendingRoute = nil
        case .settings:
            showSettings = true
            router.pendingRoute = nil
        case .canvas:
            router.pendingRoute = nil
        case nil:
            return
        }
    }

    // MARK: Clipboard monitoring

    // Polls the system clipboard every second using Swift's structured concurrency.
    // The while loop runs until the parent .task(id:) cancels this async context
    // (e.g. when the active workspace changes or the view disappears).
    private func listenForClipboardChanges() async {
        lastObservedClipboard = PasteboardService.readContent()?.fingerprint
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard let content = PasteboardService.readContent() else { continue }
            let fingerprint = content.fingerprint
            guard fingerprint != lastObservedClipboard else { continue }
            lastObservedClipboard = fingerprint
            captureClipboardContent(content)
        }
    }

    private func captureClipboardContent(_ content: PasteboardContent) {
        guard let workspace = activeWorkspace else { return }
        insertCard(content: content, method: .quickAction, workspace: workspace)
        showFeedback("Captured from clipboard")
    }

    // MARK: Workspace management

    private func renameWorkspace(_ workspace: Workspace, name: String) {
        workspace.name = name
        workspace.updatedAt = Date()
    }

    private func deleteWorkspace(_ workspace: Workspace) {
        let wasActive = workspace.isActive
        modelContext.delete(workspace)
        if wasActive, let next = workspaces.first(where: { $0.id != workspace.id }) {
            next.isActive = true
            next.updatedAt = Date()
        }
        selectedCardIDs.removeAll()
    }

    private func activateWorkspace(_ id: UUID) {
        guard workspaces.contains(where: { $0.id == id }) else { return }
        // Only touch workspaces whose isActive value actually changes — avoids
        // unnecessary SwiftData writes and updatedAt bumps on unchanged records.
        for workspace in workspaces {
            let shouldBeActive = workspace.id == id
            if workspace.isActive != shouldBeActive {
                workspace.isActive = shouldBeActive
                workspace.updatedAt = Date()
            }
        }
        selectedCardIDs.removeAll()
    }

    private func createWorkspace() {
        // The newly inserted workspace won't appear in the @Query result until the
        // next render cycle, so we can't go through activateWorkspace() here.
        // Deactivate all existing workspaces directly, then create the new one as active.
        for workspace in workspaces {
            if workspace.isActive {
                workspace.isActive = false
                workspace.updatedAt = Date()
            }
        }
        modelContext.insert(Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        ))
        selectedCardIDs.removeAll()
    }

    // MARK: Card operations

    private func pasteToCanvas(method: CaptureMethod) {
        guard let workspace = activeWorkspace else {
            showFeedback("No active workspace")
            return
        }
        guard let content = PasteboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        lastObservedClipboard = content.fingerprint   // prevent the clipboard watcher from re-importing this
        insertCard(content: content, method: method, workspace: workspace)
        showFeedback(method == .manualPaste ? "Added clipboard" : "Opened in workspace")
    }

    private func addDroppedContent(_ payload: SnippetDragPayload, at point: CGPoint) {
        guard let workspace = activeWorkspace else { return }
        let content: PasteboardContent = payload.imageData.map { .image($0, uti: "public.png") } ?? .text(payload.text)
        insertCard(content: content, method: .manualPaste, workspace: workspace, x: point.x, y: point.y)
        showFeedback("Dropped on canvas")
    }

    private func addSnippetToCanvas(_ snippet: Snippet) {
        guard let workspace = activeWorkspace else { return }
        let position = workspace.nextCardPosition()
        let card = workspace.addCard(snippet: snippet, x: position.x, y: position.y)
        selectedCardIDs = [card.id]
        showFeedback("Added to canvas")
    }

    private func copySnippet(_ snippet: Snippet) {
        PasteboardService.writeSnippet(snippet)
        markClipboardObserved(for: snippet)
        showFeedback("Copied")
    }

    private func openChatForSelection() {
        showChatPanel = true
    }

    private func openChat(for card: WorkspaceCard) {
        selectedCardIDs = [card.id]
        showChatPanel = true
    }

    private func addBlankCard() {
        guard let workspace = activeWorkspace else { return }
        insertCard(content: .text(""), method: .manualPaste, workspace: workspace, editAfterInsert: true)
    }

    private func insertCard(
        content: PasteboardContent,
        method: CaptureMethod,
        workspace: Workspace,
        editAfterInsert: Bool = false,
        offset: Double = 0,
        x: Double? = nil,
        y: Double? = nil
    ) {
        let snippet = Snippet.make(from: content, capturedBy: method)
        modelContext.insert(snippet)
        let position = workspace.nextCardPosition(offset: offset)
        let card = workspace.addCard(
            snippet: snippet,
            x: x ?? position.x,
            y: y ?? position.y
        )
        selectedCardIDs = [card.id]
        if editAfterInsert { editingCard = card }
    }

    private func insertChatReply(_ text: String) {
        guard let workspace = activeWorkspace else { return }
        insertCard(content: .text(text), method: .transformResult, workspace: workspace, offset: 80)
        showFeedback("Reply added to canvas")
    }

    private func runTransform(_ kind: TransformKind) {
        guard let workspace = activeWorkspace else { return }
        let cards = selectedCards
        let input = cards.compactMap { $0.snippet?.text }.filter { !$0.isEmpty }.joined(separator: "\n\n")
        guard !input.isEmpty else {
            showFeedback("Select a card with text")
            return
        }

        let run = TransformRun(
            workspace: workspace,
            inputCardIDs: cards.map(\.id),
            kind: kind,
            inputText: input
        )
        modelContext.insert(run)
        runningTransforms.insert(run.id)

        // Task { } creates a concurrent async context without blocking the main thread.
        // The closure captures `run`, `workspace`, and `kind` by reference.
        Task {
            do {
                let output = try await TransformService.perform(kind, on: input)
                run.outputText = output
                run.status = .done
                let resultSnippet = Snippet.make(from: output, capturedBy: .transformResult)
                modelContext.insert(resultSnippet)
                let anchor = cards.first
                let card = workspace.addCard(
                    snippet: resultSnippet,
                    transformRun: run,
                    x: (anchor?.x ?? 180) + 280,
                    y: (anchor?.y ?? 160) + 36,
                    width: 280,
                    height: 180
                )
                selectedCardIDs = [card.id]
                showFeedback("\(kind.label) complete")
            } catch {
                run.status = .failed
                run.errorMessage = error.localizedDescription
                showFeedback(error.localizedDescription)
            }
            runningTransforms.remove(run.id)
            workspace.updatedAt = Date()
        }
    }

    private func copyCard(_ card: WorkspaceCard) {
        guard let snippet = card.snippet else { return }
        PasteboardService.writeSnippet(snippet)
        markClipboardObserved(for: snippet)
        showFeedback("Copied")
    }

    private func deleteCard(_ card: WorkspaceCard) {
        selectedCardIDs.remove(card.id)
        modelContext.delete(card)
        activeWorkspace?.updatedAt = Date()
    }

    private func duplicateCard(_ card: WorkspaceCard) {
        guard let workspace = activeWorkspace, let source = card.snippet else { return }
        let content: PasteboardContent = source.imageData.map { .image($0, uti: source.imageUTI ?? "public.png") } ?? .text(source.text)
        let snippet = Snippet.make(from: content, capturedBy: source.captureMethod)
        modelContext.insert(snippet)
        let copy = workspace.addCard(
            snippet: snippet,
            transformRun: card.transformRun,
            x: card.x + 28,
            y: card.y + 28,
            width: card.width,
            height: card.height,
            color: card.color
        )
        selectedCardIDs = [copy.id]
    }

    private func moveCards(ids: Set<UUID>, by translation: CGSize, scale: CGFloat) {
        guard let workspace = activeWorkspace else { return }
        for card in workspace.cards where ids.contains(card.id) {
            card.x += translation.width / scale
            card.y += translation.height / scale
            card.updatedAt = Date()
        }
        workspace.updatedAt = Date()
    }

    private func copySelectedCards() {
        if selectedCards.count == 1, let snippet = selectedCards.first?.snippet {
            PasteboardService.writeSnippet(snippet)
            markClipboardObserved(for: snippet)
            showFeedback("Copied 1 card")
            return
        }
        let text = selectedCards
            .compactMap { $0.snippet?.text }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !text.isEmpty else {
            showFeedback("Selected cards are empty")
            return
        }
        PasteboardService.writeString(text)
        lastObservedClipboard = PasteboardContent.text(text).fingerprint
        showFeedback("Copied \(selectedCards.count) card\(selectedCards.count == 1 ? "" : "s")")
    }

    private var selectedArePrivate: Bool {
        !selectedCards.isEmpty && selectedCards.allSatisfy { $0.snippet?.sensitivity == .privateContent }
    }

    private func toggleSelectedPrivacy() {
        let target: Sensitivity = selectedArePrivate ? .normal : .privateContent
        for card in selectedCards { card.snippet?.sensitivity = target }
        showFeedback(target == .privateContent ? "Marked as private" : "Marked as normal")
    }

    private func deleteSelectedCards() {
        let cards = selectedCards
        guard !cards.isEmpty else { return }
        for card in cards { modelContext.delete(card) }
        selectedCardIDs.removeAll()
        activeWorkspace?.updatedAt = Date()
        showFeedback("Deleted \(cards.count) card\(cards.count == 1 ? "" : "s")")
    }

    // MARK: Helpers

    private func showFeedback(_ message: String) {
        withAnimation { feedback = message }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }

    private func markClipboardObserved(for snippet: Snippet) {
        // Updating lastObservedClipboard here prevents the clipboard watcher from
        // re-importing content that the user just copied OUT of ClipCanvas.
        if let imageData = snippet.imageData {
            lastObservedClipboard = PasteboardContent.image(imageData, uti: snippet.imageUTI ?? "public.png").fingerprint
        } else {
            lastObservedClipboard = PasteboardContent.text(snippet.text).fingerprint
        }
    }
}
