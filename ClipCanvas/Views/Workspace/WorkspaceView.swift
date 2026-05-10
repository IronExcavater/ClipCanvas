import SwiftData
import SwiftUI

struct WorkspaceView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workspace> { !$0.isArchived },
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]

    @State private var selectedCardIDs = Set<UUID>()
    @State private var editingCard: WorkspaceCard?
    @State private var showChatPanel = false
    @State private var showSettings = false
    @State private var feedback: String?
    @State private var runningTransforms = Set<UUID>()
    @State private var chatContextCardIDs = Set<UUID>()
    @State private var droppedChatContext: [String] = []
    @State private var lastObservedClipboard: String?

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var selectedCards: [WorkspaceCard] {
        guard let workspace = activeWorkspace else { return [] }
        return workspace.cards.filter { selectedCardIDs.contains($0.id) }
    }

    private var chatContextCards: [WorkspaceCard] {
        guard let workspace = activeWorkspace else { return [] }
        return workspace.cards.filter { chatContextCardIDs.contains($0.id) }
    }

    var body: some View {
        HStack(spacing: 0) {
            WorkspaceSidebar(
                workspaces: workspaces,
                snippets: Array(snippets.prefix(60)),
                activeWorkspace: activeWorkspace,
                selectedCount: selectedCardIDs.count,
                activateWorkspace: activateWorkspace,
                createWorkspace: createWorkspace,
                addSnippetToCanvas: addSnippetToCanvas,
                copySnippet: copySnippet
            )
            .frame(width: 280)

            Divider()

            VStack(spacing: 0) {
                WorkspaceTopBar(
                    workspace: activeWorkspace,
                    selectedCount: selectedCardIDs.count,
                    isChatVisible: showChatPanel,
                    paste: { pasteToCanvas(method: .manualPaste) },
                    addCard: addBlankCard,
                    transform: runTransform,
                    chat: openChatForSelection,
                    copySelected: copySelectedCards,
                    deleteSelected: deleteSelectedCards,
                    clearSelection: { selectedCardIDs.removeAll() },
                    toggleChat: { showChatPanel.toggle() },
                    openSettings: { showSettings = true }
                )

                Divider()

                ZStack(alignment: .top) {
                    HStack(spacing: 0) {
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
                            addDroppedText: addDroppedText
                        )

                        if showChatPanel, let workspace = activeWorkspace {
                            Divider()
                            WorkspaceChatPanel(
                                workspace: workspace,
                                contextCards: chatContextCards,
                                extraContext: $droppedChatContext,
                                insertReply: insertChatReply,
                                close: { showChatPanel = false }
                            )
                            .frame(width: 360)
                            .background(.regularMaterial)
                        }
                    }

                    if let feedback {
                        Text(feedback)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 10)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
        }
        .sheet(item: $editingCard) { card in
            CardEditSheet(card: card)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: router.pendingRoute) { _, route in
            consumePendingRoute(route)
        }
        .task {
            AppBootstrap.ensureActiveWorkspace(in: modelContext)
            consumePendingRoute(router.pendingRoute)
        }
        .task(id: activeWorkspace?.id) {
            await listenForClipboardChanges()
        }
        .animation(.snappy(duration: 0.18), value: showChatPanel)
        .animation(.spring(duration: 0.25), value: feedback)
    }

    private func consumePendingRoute(_ route: AppRoute?) {
        if case .workspace(let id) = route {
            activateWorkspace(id)
            router.pendingRoute = nil
            return
        }
        guard route == .copyToCanvas else { return }
        pasteToCanvas(method: router.pendingPasteMethod ?? .quickAction)
        router.pendingRoute = nil
        router.pendingPasteMethod = nil
    }

    private func listenForClipboardChanges() async {
        lastObservedClipboard = PasteboardService.readString()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard let text = PasteboardService.readString(), !text.isEmpty else { continue }
            guard text != lastObservedClipboard else { continue }
            lastObservedClipboard = text
            captureClipboardText(text)
        }
    }

    private func captureClipboardText(_ text: String) {
        guard let workspace = activeWorkspace else { return }
        if snippets.first?.text == text { return }
        insertCard(text: text, method: .quickAction, workspace: workspace)
        showFeedback("Captured from clipboard")
    }

    private func activateWorkspace(_ workspace: Workspace) {
        activateWorkspace(workspace.id)
    }

    private func activateWorkspace(_ id: UUID) {
        guard let target = workspaces.first(where: { $0.id == id }) else { return }
        for workspace in workspaces {
            workspace.isActive = workspace.id == target.id
            workspace.updatedAt = Date()
        }
        selectedCardIDs.removeAll()
    }

    private func createWorkspace() {
        let workspace = Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        modelContext.insert(workspace)
        activateWorkspace(workspace)
    }

    private func pasteToCanvas(method: CaptureMethod) {
        guard let workspace = activeWorkspace else {
            showFeedback("No active workspace")
            return
        }
        guard let text = PasteboardService.readString() else {
            showFeedback("Clipboard is empty")
            return
        }
        lastObservedClipboard = text
        insertCard(text: text, method: method, workspace: workspace)
        showFeedback(method == .manualPaste ? "Added clipboard" : "Opened in workspace")
    }

    private func addDroppedText(_ text: String, at point: CGPoint) {
        guard let workspace = activeWorkspace else { return }
        insertCard(text: text, method: .manualPaste, workspace: workspace, x: point.x, y: point.y)
        showFeedback("Dropped on canvas")
    }

    private func addSnippetToCanvas(_ snippet: Snippet) {
        guard let workspace = activeWorkspace else { return }
        let index = Double(workspace.cards.count)
        let card = WorkspaceCard(
            snippet: snippet,
            x: 180 + (index.truncatingRemainder(dividingBy: 5) * 28),
            y: 160 + (index.truncatingRemainder(dividingBy: 7) * 22),
            color: color(for: snippet)
        )
        card.workspace = workspace
        workspace.cards.append(card)
        workspace.updatedAt = Date()
        selectedCardIDs = [card.id]
        showFeedback("Added to canvas")
    }

    private func copySnippet(_ snippet: Snippet) {
        PasteboardService.writeString(snippet.text)
        lastObservedClipboard = snippet.text
        showFeedback("Copied")
    }

    private func openChatForSelection() {
        chatContextCardIDs.formUnion(selectedCardIDs)
        showChatPanel = true
    }

    private func openChat(for card: WorkspaceCard) {
        chatContextCardIDs.insert(card.id)
        selectedCardIDs = [card.id]
        showChatPanel = true
    }

    private func addBlankCard() {
        guard let workspace = activeWorkspace else { return }
        insertCard(text: "", method: .manualPaste, workspace: workspace, editAfterInsert: true)
    }

    private func insertCard(
        text: String,
        method: CaptureMethod,
        workspace: Workspace,
        editAfterInsert: Bool = false,
        offset: Double = 0,
        x: Double? = nil,
        y: Double? = nil
    ) {
        let snippet = Snippet.make(from: text, capturedBy: method)
        modelContext.insert(snippet)
        let index = Double(workspace.cards.count)
        let card = WorkspaceCard(
            snippet: snippet,
            x: x ?? 180 + offset + (index.truncatingRemainder(dividingBy: 5) * 28),
            y: y ?? 160 + offset + (index.truncatingRemainder(dividingBy: 7) * 22),
            width: snippet.type == .code ? 280 : 240,
            height: snippet.type == .code ? 190 : 160,
            color: color(for: snippet)
        )
        card.workspace = workspace
        workspace.cards.append(card)
        workspace.updatedAt = Date()
        selectedCardIDs = [card.id]
        if editAfterInsert { editingCard = card }
    }

    private func insertChatReply(_ text: String) {
        guard let workspace = activeWorkspace else { return }
        insertCard(text: text, method: .transformResult, workspace: workspace, offset: 80)
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
            operationLabel: kind.label,
            inputText: input
        )
        modelContext.insert(run)
        runningTransforms.insert(run.id)

        Task {
            do {
                let output = try await TransformService.perform(kind, on: input)
                run.outputText = output
                run.status = .done
                let resultSnippet = Snippet.make(from: output, capturedBy: .transformResult)
                modelContext.insert(resultSnippet)
                let anchor = cards.first
                let card = WorkspaceCard(
                    snippet: resultSnippet,
                    transformRun: run,
                    x: (anchor?.x ?? 180) + 280,
                    y: (anchor?.y ?? 160) + 36,
                    width: 280,
                    height: 180,
                    color: .green
                )
                card.workspace = workspace
                workspace.cards.append(card)
                selectedCardIDs = [card.id]
                chatContextCardIDs.insert(card.id)
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
        guard let text = card.snippet?.text, !text.isEmpty else { return }
        PasteboardService.writeString(text)
        lastObservedClipboard = text
        showFeedback("Copied")
    }

    private func deleteCard(_ card: WorkspaceCard) {
        selectedCardIDs.remove(card.id)
        modelContext.delete(card)
        activeWorkspace?.updatedAt = Date()
    }

    private func duplicateCard(_ card: WorkspaceCard) {
        guard let workspace = activeWorkspace, let text = card.snippet?.text else { return }
        let snippet = Snippet.make(from: text, capturedBy: card.snippet?.captureMethod ?? .manualPaste)
        modelContext.insert(snippet)
        let copy = WorkspaceCard(
            snippet: snippet,
            transformRun: card.transformRun,
            x: card.x + 28,
            y: card.y + 28,
            width: card.width,
            height: card.height,
            color: card.color
        )
        copy.workspace = workspace
        workspace.cards.append(copy)
        selectedCardIDs = [copy.id]
    }

    private func moveCards(ids: Set<UUID>, by translation: CGSize, scale: CGFloat) {
        guard let workspace = activeWorkspace else { return }
        let dx = translation.width / scale
        let dy = translation.height / scale
        for card in workspace.cards where ids.contains(card.id) {
            card.x += dx
            card.y += dy
            card.updatedAt = Date()
        }
        workspace.updatedAt = Date()
    }

    private func copySelectedCards() {
        let text = selectedCards
            .compactMap { $0.snippet?.text }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !text.isEmpty else {
            showFeedback("Selected cards are empty")
            return
        }
        PasteboardService.writeString(text)
        lastObservedClipboard = text
        showFeedback("Copied \(selectedCards.count) card\(selectedCards.count == 1 ? "" : "s")")
    }

    private func deleteSelectedCards() {
        let cards = selectedCards
        guard !cards.isEmpty else { return }
        for card in cards {
            modelContext.delete(card)
        }
        selectedCardIDs.removeAll()
        activeWorkspace?.updatedAt = Date()
        showFeedback("Deleted \(cards.count) card\(cards.count == 1 ? "" : "s")")
    }

    private func color(for snippet: Snippet) -> CardColor {
        switch snippet.captureMethod {
        case .transformResult: .green
        case .quickAction, .appIntent: .blue
        case .manualPaste:
            switch snippet.type {
            case .code: .purple
            case .url: .yellow
            case .text: .default
            }
        }
    }

    private func showFeedback(_ message: String) {
        withAnimation { feedback = message }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }
}

private struct WorkspaceSidebar: View {
    let workspaces: [Workspace]
    let snippets: [Snippet]
    let activeWorkspace: Workspace?
    let selectedCount: Int
    let activateWorkspace: (Workspace) -> Void
    let createWorkspace: () -> Void
    let addSnippetToCanvas: (Snippet) -> Void
    let copySnippet: (Snippet) -> Void

    @State private var searchText = ""

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("ClipCanvas", systemImage: "rectangle.3.group.bubble.left")
                        .font(.headline)
                    Spacer()
                    Button(action: createWorkspace) {
                        Image(systemName: "plus")
                    }
                    .help("New canvas")
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(activeWorkspace?.name ?? "Canvas")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label("\(activeWorkspace?.cards.count ?? 0)", systemImage: "square.stack.3d.up")
                        if selectedCount > 0 {
                            Label("\(selectedCount)", systemImage: "checkmark.circle")
                        }
                        Label("Listening", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            List {
                Section("Canvases") {
                    ForEach(workspaces) { workspace in
                        WorkspaceSidebarRow(workspace: workspace)
                            .contentShape(Rectangle())
                            .onTapGesture { activateWorkspace(workspace) }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(height: 190)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Recent", systemImage: "tray.full")
                        .font(.headline)
                    Spacer()
                    Text("\(snippets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Search history", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding([.horizontal, .top], 16)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredSnippets.isEmpty {
                        ContentUnavailableView("No clips", systemImage: "doc.on.clipboard")
                            .frame(minHeight: 180)
                    } else {
                        ForEach(filteredSnippets) { snippet in
                            SnippetLibraryCard(
                                snippet: snippet,
                                addToCanvas: { addSnippetToCanvas(snippet) },
                                copy: { copySnippet(snippet) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
        }
        .background(.regularMaterial)
    }
}

private struct WorkspaceSidebarRow: View {
    let workspace: Workspace

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: workspace.isActive ? "largecircle.fill.circle" : "rectangle.dashed")
                .foregroundStyle(workspace.isActive ? Color.accentColor : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .lineLimit(1)
                Text("\(workspace.cards.count) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if workspace.isActive {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

private struct SnippetLibraryCard: View {
    let snippet: Snippet
    let addToCanvas: () -> Void
    let copy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                SourceGlyph(snippet: snippet)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.sourceTitle)
                        .font(.caption.weight(.semibold))
                    HStack(spacing: 4) {
                        Text(snippet.sourceDetail)
                        Text("-")
                        Text(snippet.createdAt, style: .relative)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: addToCanvas) {
                    Image(systemName: "plus.square.on.square")
                }
                .buttonStyle(.borderless)
                .help("Add to canvas")
            }

            Text(snippet.preview)
                .font(snippet.type == .code ? .system(.caption, design: .monospaced) : .callout)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(snippet.cardVariant.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(snippet.cardVariant.accent.opacity(0.24), lineWidth: 1)
        }
        .contextMenu {
            Button("Add to Canvas", systemImage: "plus.square.on.square", action: addToCanvas)
            Button("Copy", systemImage: "doc.on.doc", action: copy)
        }
        .draggable(snippet.text)
    }
}

private struct WorkspaceTopBar: View {
    let workspace: Workspace?
    let selectedCount: Int
    let isChatVisible: Bool
    let paste: () -> Void
    let addCard: () -> Void
    let transform: (TransformKind) -> Void
    let chat: () -> Void
    let copySelected: () -> Void
    let deleteSelected: () -> Void
    let clearSelection: () -> Void
    let toggleChat: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace?.name ?? "Canvas")
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 7, height: 7)
                    Text("Listening to clipboard")
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if selectedCount > 0 {
                Text("\(selectedCount) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(TransformKind.allCases, id: \.self) { kind in
                        Button(kind.label) { transform(kind) }
                    }
                } label: {
                    Label("Transform", systemImage: "wand.and.sparkles")
                }
                Button(action: chat) {
                    Label("Ask", systemImage: "bubble.left.and.bubble.right")
                }
                Button(action: copySelected) {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy selected")
                Button(role: .destructive, action: deleteSelected) {
                    Image(systemName: "trash")
                }
                .help("Delete selected")
                Button(action: clearSelection) {
                    Image(systemName: "xmark")
                }
                .help("Clear selection")
            } else {
                Button(action: paste) {
                    Label("Capture", systemImage: "doc.on.clipboard")
                }
                .help("Add clipboard to canvas")
                Button(action: addCard) {
                    Image(systemName: "plus")
                }
                .help("New card")
            }

            Divider()
                .frame(height: 24)

            Button(action: toggleChat) {
                Image(systemName: isChatVisible ? "sidebar.right" : "sparkles")
            }
            .help("Toggle AI workspace")
            Button(action: openSettings) {
                Image(systemName: "gearshape")
            }
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct CanvasSurface: View {
    let workspace: Workspace?
    @Binding var selectedCardIDs: Set<UUID>
    @Binding var editingCard: WorkspaceCard?
    let runningTransforms: Set<UUID>
    let openChatForCard: (WorkspaceCard) -> Void
    let copyCard: (WorkspaceCard) -> Void
    let deleteCard: (WorkspaceCard) -> Void
    let duplicateCard: (WorkspaceCard) -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void
    let addDroppedText: (String, CGPoint) -> Void

    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1
    @State private var baseScale: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                DotGrid(offset: canvasOffset, scale: canvasScale)
                    .gesture(panGesture)
                    .onTapGesture { selectedCardIDs.removeAll() }

                if let workspace, workspace.cards.isEmpty {
                    EmptyCanvasHint()
                }

                if let workspace {
                    ZStack(alignment: .topLeading) {
                        ForEach(workspace.cards) { card in
                            CanvasCardView(
                                card: card,
                                canvasScale: canvasScale,
                                isSelected: selectedCardIDs.contains(card.id),
                                isRunning: card.transformRun.map { runningTransforms.contains($0.id) } ?? false,
                                selectedCardIDs: selectedCardIDs,
                                select: { select(card) },
                                ask: { openChatForCard(card) },
                                edit: { editingCard = card },
                                copy: { copyCard(card) },
                                duplicate: { duplicateCard(card) },
                                delete: { deleteCard(card) },
                                moveCards: moveCards
                            )
                            .position(x: card.x, y: card.y)
                            .zIndex(selectedCardIDs.contains(card.id) ? 20 : (card.transformRun == nil ? 1 : 2))
                        }
                    }
                    .scaleEffect(canvasScale, anchor: .topLeading)
                    .offset(canvasOffset)
                }

                CanvasControlStrip(
                    scale: canvasScale,
                    zoomOut: { zoom(by: 0.85) },
                    zoomIn: { zoom(by: 1.15) },
                    fit: { fitWorkspace(in: proxy) },
                    reset: resetView
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18)
            }
            .dropDestination(for: String.self) { items, location in
                guard let text = items.first?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    return false
                }
                let canvasPoint = CGPoint(
                    x: (location.x - canvasOffset.width) / canvasScale,
                    y: (location.y - canvasOffset.height) / canvasScale
                )
                addDroppedText(text, canvasPoint)
                return true
            }
            .clipped()
            .simultaneousGesture(zoomGesture(proxy: proxy))
        }
        .background(Color.clipCanvasPageBackground)
    }

    private func select(_ card: WorkspaceCard) {
        if selectedCardIDs.contains(card.id) {
            selectedCardIDs.remove(card.id)
        } else {
            selectedCardIDs.insert(card.id)
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                canvasOffset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in baseOffset = canvasOffset }
    }

    private func zoomGesture(proxy: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let nextScale = min(max(baseScale * value, 0.35), 3)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                canvasOffset = CGSize(
                    width: center.x - (center.x - baseOffset.width) * nextScale / baseScale,
                    height: center.y - (center.y - baseOffset.height) * nextScale / baseScale
                )
                canvasScale = nextScale
            }
            .onEnded { _ in
                baseScale = canvasScale
                baseOffset = canvasOffset
            }
    }

    private func zoom(by factor: CGFloat) {
        let nextScale = min(max(canvasScale * factor, 0.35), 3)
        withAnimation(.snappy(duration: 0.16)) {
            canvasScale = nextScale
            baseScale = nextScale
        }
    }

    private func fitWorkspace(in proxy: GeometryProxy) {
        guard let cards = workspace?.cards, !cards.isEmpty else {
            resetView()
            return
        }

        let bounds = cards.reduce(CGRect.null) { rect, card in
            rect.union(
                CGRect(
                    x: CGFloat(card.x - card.width / 2),
                    y: CGFloat(card.y - card.height / 2),
                    width: CGFloat(card.width),
                    height: CGFloat(card.height)
                )
            )
        }
        guard !bounds.isNull, bounds.width > 0, bounds.height > 0 else { return }

        let padding: CGFloat = 96
        let availableWidth = max(proxy.size.width - padding, 240)
        let availableHeight = max(proxy.size.height - padding, 180)
        let nextScale = min(max(min(availableWidth / bounds.width, availableHeight / bounds.height), 0.35), 1.35)
        let nextOffset = CGSize(
            width: proxy.size.width / 2 - bounds.midX * nextScale,
            height: proxy.size.height / 2 - bounds.midY * nextScale
        )

        withAnimation(.snappy(duration: 0.22)) {
            canvasScale = nextScale
            baseScale = nextScale
            canvasOffset = nextOffset
            baseOffset = nextOffset
        }
    }

    private func resetView() {
        withAnimation(.snappy(duration: 0.18)) {
            canvasOffset = .zero
            baseOffset = .zero
            canvasScale = 1
            baseScale = 1
        }
    }
}

private struct CanvasCardView: View {
    @Bindable var card: WorkspaceCard
    let canvasScale: CGFloat
    let isSelected: Bool
    let isRunning: Bool
    let selectedCardIDs: Set<UUID>
    let select: () -> Void
    let ask: () -> Void
    let edit: () -> Void
    let copy: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero

    private var renderedWidth: CGFloat {
        min(max(170, card.width + resizeOffset.width / canvasScale), 420)
    }

    private var renderedHeight: CGFloat {
        min(max(120, card.height + resizeOffset.height / canvasScale), 360)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SourceGlyph(snippet: card.snippet)
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.snippet?.sourceTitle ?? "Card")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    if let snippet = card.snippet {
                        HStack(spacing: 4) {
                            Text(snippet.sourceDetail)
                            Text("-")
                            Text(snippet.createdAt, style: .relative)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if card.transformRun != nil {
                    Image(systemName: "wand.and.sparkles")
                        .foregroundStyle(.green)
                }
            }

            Text(displayText)
                .font(card.snippet?.type == .code ? .system(.callout, design: .monospaced) : .body)
                .foregroundStyle(displayTextIsPlaceholder ? .secondary : .primary)
                .lineLimit(7)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: renderedWidth, height: renderedHeight, alignment: .topLeading)
        .background(card.color.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(card.color.accent)
                .frame(height: 3)
                .clipShape(.rect(topLeadingRadius: 8, topTrailingRadius: 8))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : card.color.accent.opacity(0.22), lineWidth: isSelected ? 2.5 : 1)
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                ResizeHandle()
                    .padding(6)
                    .gesture(resizeDrag)
            }
        }
        .overlay {
            if isRunning {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                ProgressView()
            }
        }
        .offset(dragOffset)
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0.08), radius: isSelected ? 12 : 5, y: isSelected ? 7 : 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .gesture(cardDrag)
        .contextMenu {
            Button("Ask About This", systemImage: "bubble.left.and.bubble.right", action: ask)
            Button("Edit", systemImage: "pencil", action: edit)
            Button("Copy", systemImage: "doc.on.doc", action: copy)
            Button("Duplicate", systemImage: "plus.square.on.square", action: duplicate)
            Menu("Color") {
                ForEach(CardColor.allCases, id: \.self) { color in
                    Button(color.label) { card.color = color }
                }
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: delete)
        }
        .draggable(card.snippet?.text ?? displayText)
    }

    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let movingIDs = isSelected ? selectedCardIDs : [card.id]
                if movingIDs.count > 1 {
                    moveCards(movingIDs, value.translation, canvasScale)
                } else {
                    card.x += value.translation.width / canvasScale
                    card.y += value.translation.height / canvasScale
                    card.updatedAt = Date()
                }
                dragOffset = .zero
            }
    }

    private var resizeDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                resizeOffset = value.translation
            }
            .onEnded { value in
                card.width = min(max(170, card.width + value.translation.width / canvasScale), 420)
                card.height = min(max(120, card.height + value.translation.height / canvasScale), 360)
                card.updatedAt = Date()
                resizeOffset = .zero
            }
    }

    private var displayText: String {
        guard let text = card.snippet?.preview, !text.isEmpty else { return "Empty card" }
        return text
    }

    private var displayTextIsPlaceholder: Bool {
        card.snippet?.text.isEmpty ?? true
    }
}

private struct CanvasControlStrip: View {
    let scale: CGFloat
    let zoomOut: () -> Void
    let zoomIn: () -> Void
    let fit: () -> Void
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
            }
            Text("\(Int(scale * 100))%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .frame(width: 48)
            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
            }
            Divider()
                .frame(height: 22)
            Button(action: fit) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .help("Fit board")
            Button(action: reset) {
                Image(systemName: "arrow.counterclockwise")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.08))
        }
    }
}

private struct ResizeHandle: View {
    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.16), radius: 6, y: 3)
    }
}

private struct CardEditSheet: View {
    @Bindable var card: WorkspaceCard
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Edit Card")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: save)
                    }
                }
                .onAppear { text = card.snippet?.text ?? "" }
        }
    }

    private func save() {
        card.snippet?.text = text
        card.updatedAt = Date()
        dismiss()
    }
}

private struct DotGrid: View {
    let offset: CGSize
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let spacing = max(24 * scale, 12)
            let radius = min(1.2 * scale, 2)
            var x = offset.width.truncatingRemainder(dividingBy: spacing)
            if x < 0 { x += spacing }
            while x < size.width + spacing {
                var y = offset.height.truncatingRemainder(dividingBy: spacing)
                if y < 0 { y += spacing }
                while y < size.height + spacing {
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(.secondary.opacity(0.22))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
    }
}

private struct EmptyCanvasHint: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.3.group.bubble.left")
                .font(.system(size: 38))
                .foregroundStyle(.tertiary)
            Text("Your clipboard becomes a workspace")
                .font(.headline)
            Text("Copy text anywhere, use Add Clipboard, or drag a clip from the sidebar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
