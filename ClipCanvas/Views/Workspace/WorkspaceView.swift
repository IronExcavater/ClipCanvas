import SwiftData
import SwiftUI

struct WorkspaceView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(
        filter: #Predicate<Workspace> { !$0.isArchived },
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]
    @Query(sort: \Snippet.createdAt, order: .reverse) private var snippets: [Snippet]

    @State private var selectedCardIDs = Set<UUID>()
    @State private var editingCard: WorkspaceCard?
    @State private var showSettings = false
    @State private var showLibrary = false
    @State private var feedback: String?
    @State private var runningTransforms = Set<UUID>()
    @State private var lastObservedClipboard: String?
    @State private var showSidebar = false

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    private var selectedCards: [WorkspaceCard] {
        guard let workspace = activeWorkspace else { return [] }
        return workspace.cards.filter { selectedCardIDs.contains($0.id) }
    }

    var body: some View {
        mainContent
            .sheet(item: $editingCard) { card in
                CardEditSheet(card: card)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showLibrary) {
                LibraryView()
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
            .animation(.spring(duration: 0.25), value: feedback)
    }

    @ViewBuilder
    private var mainContent: some View {
        GeometryReader { proxy in
            let isVertical = sizeClass == .compact || proxy.size.width < 760 || proxy.size.height > proxy.size.width * 1.25
            if isVertical {
                ZStack(alignment: .leading) {
                    canvasContent(toggleSidebar: { withAnimation { showSidebar.toggle() } }, isNarrow: true)
                    if showSidebar {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation { showSidebar = false } }
                        sidebar
                            .transition(.move(edge: .leading))
                    }
                }
                .animation(.spring(duration: 0.25), value: showSidebar)
            } else {
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
            activateWorkspace: activateWorkspace,
            createWorkspace: createWorkspace,
            addSnippetToCanvas: addSnippetToCanvas,
            copySnippet: copySnippet,
            openLibrary: { showLibrary = true }
        )
        .frame(width: 252)
    }

    private var canvasSurface: some View {
        CanvasSurface(
            workspace: activeWorkspace,
            selectedCardIDs: $selectedCardIDs,
            editingCard: $editingCard,
            runningTransforms: runningTransforms,
            copyCard: copyCard,
            deleteCard: deleteCard,
            duplicateCard: duplicateCard,
            moveCards: moveCards,
            addDroppedContent: addDroppedContent
        )
    }

    @ViewBuilder
    private func canvasContent(toggleSidebar: (() -> Void)?, isNarrow: Bool) -> some View {
        VStack(spacing: 0) {
            WorkspaceTopBar(
                workspace: activeWorkspace,
                selectedCount: selectedCardIDs.count,
                isNarrow: isNarrow,
                paste: { pasteToCanvas(method: .manualPaste) },
                addCard: addBlankCard,
                transform: runTransform,
                copySelected: copySelectedCards,
                deleteSelected: deleteSelectedCards,
                clearSelection: { selectedCardIDs.removeAll() },
                selectedArePrivate: selectedArePrivate,
                togglePrivacy: toggleSelectedPrivacy,
                openLibrary: { showLibrary = true },
                openSettings: { showSettings = true },
                toggleSidebar: toggleSidebar
            )

            Divider()

            ZStack(alignment: .top) {
                if isNarrow {
                    VStack(spacing: 0) {
                        canvasSurface
                    }
                } else {
                    HStack(spacing: 0) {
                        canvasSurface
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
        if case .text(let text) = content, snippets.first?.text == text { return }
        insertCard(content: content, method: .quickAction, workspace: workspace)
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
        guard let content = PasteboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        lastObservedClipboard = content.fingerprint
        insertCard(content: content, method: method, workspace: workspace)
        showFeedback(method == .manualPaste ? "Added clipboard" : "Opened in workspace")
    }

    private func addDroppedContent(_ payload: SnippetDragPayload, at point: CGPoint) {
        guard let workspace = activeWorkspace else { return }
        let content: PasteboardContent
        if let imageData = payload.imageData {
            content = .image(imageData, uti: "public.png")
        } else {
            content = .text(payload.text)
        }
        insertCard(content: content, method: .manualPaste, workspace: workspace, x: point.x, y: point.y)
        showFeedback("Dropped on canvas")
    }

    private func addSnippetToCanvas(_ snippet: Snippet) {
        guard let workspace = activeWorkspace else { return }
        let index = Double(workspace.cards.count)
        let card = WorkspaceCard(
            snippet: snippet,
            x: 180 + (index.truncatingRemainder(dividingBy: 5) * 28),
            y: 160 + (index.truncatingRemainder(dividingBy: 7) * 22),
            width: snippet.defaultCardSize.width,
            height: snippet.defaultCardSize.height,
            color: snippet.cardVariant
        )
        card.workspace = workspace
        workspace.cards.append(card)
        workspace.updatedAt = Date()
        selectedCardIDs = [card.id]
        showFeedback("Added to canvas")
    }

    private func copySnippet(_ snippet: Snippet) {
        PasteboardService.writeSnippet(snippet)
        lastObservedClipboard = snippet.dragText
        showFeedback("Copied")
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
        let index = Double(workspace.cards.count)
        let card = WorkspaceCard(
            snippet: snippet,
            x: x ?? 180 + offset + (index.truncatingRemainder(dividingBy: 5) * 28),
            y: y ?? 160 + offset + (index.truncatingRemainder(dividingBy: 7) * 22),
            width: snippet.defaultCardSize.width,
            height: snippet.defaultCardSize.height,
            color: snippet.cardVariant
        )
        card.workspace = workspace
        workspace.cards.append(card)
        workspace.updatedAt = Date()
        selectedCardIDs = [card.id]
        if editAfterInsert { editingCard = card }
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
                    color: resultSnippet.cardVariant
                )
                card.workspace = workspace
                workspace.cards.append(card)
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
        lastObservedClipboard = snippet.dragText
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
            lastObservedClipboard = snippet.dragText
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
        lastObservedClipboard = text
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
        for card in cards {
            modelContext.delete(card)
        }
        selectedCardIDs.removeAll()
        activeWorkspace?.updatedAt = Date()
        showFeedback("Deleted \(cards.count) card\(cards.count == 1 ? "" : "s")")
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
    let openLibrary: () -> Void

    @State private var searchText = ""

    private var filteredSnippets: [Snippet] {
        guard !searchText.isEmpty else { return snippets }
        return snippets.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activeWorkspace?.name ?? "Canvas")
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(activeWorkspace?.cards.count ?? 0) cards")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Button(action: createWorkspace) {
                            Image(systemName: "plus")
                        }
                        Button(action: openLibrary) {
                            Image(systemName: "clock")
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            List {
                ForEach(workspaces) { workspace in
                    WorkspaceSidebarRow(workspace: workspace, isActive: workspace.id == activeWorkspace?.id)
                        .contentShape(Rectangle())
                        .onTapGesture { activateWorkspace(workspace) }
                }
            }
            .listStyle(.sidebar)
            .frame(height: min(CGFloat(max(workspaces.count, 1)) * 44 + 12, 156))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Recent")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(action: openLibrary) {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderless)
                    .help("Open history")
                    Text("\(snippets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Search history", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if filteredSnippets.isEmpty {
                        Image(systemName: "doc.on.clipboard")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 120)
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
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .background(.regularMaterial)
    }
}

private struct WorkspaceSidebarRow: View {
    let workspace: Workspace
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.name)
                    .lineLimit(1)
                Text("\(workspace.cards.count) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct SnippetLibraryCard: View {
    let snippet: Snippet
    let addToCanvas: () -> Void
    let copy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            SourceGlyph(snippet: snippet)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(snippet.preview)
                        .font(snippet.type == .code ? .system(.caption, design: .monospaced) : .caption)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Button(action: addToCanvas) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(snippet.sourceTitle)
                        Text(snippet.createdAt, style: .relative)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if snippet.type == .image {
                    SnippetPreviewContent(snippet: snippet, lineLimit: 1, imageHeight: 82)
                }
            }
        }
        .padding(8)
        .background(snippet.cardVariant.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(snippet.cardVariant.accent.opacity(0.20), lineWidth: 1)
        }
        .contextMenu {
            Button("Add to Canvas", systemImage: "plus.square.on.square", action: addToCanvas)
            Button("Copy", systemImage: "doc.on.doc", action: copy)
        }
        .snippetDraggable(snippet)
    }
}

private struct WorkspaceTopBar: View {
    let workspace: Workspace?
    let selectedCount: Int
    let isNarrow: Bool
    let paste: () -> Void
    let addCard: () -> Void
    let transform: (TransformKind) -> Void
    let copySelected: () -> Void
    let deleteSelected: () -> Void
    let clearSelection: () -> Void
    let selectedArePrivate: Bool
    let togglePrivacy: () -> Void
    let openLibrary: () -> Void
    let openSettings: () -> Void
    let toggleSidebar: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let toggleSidebar {
                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                }
            }

            Text(workspace?.name ?? "Canvas")
                .font(.headline)
                .lineLimit(1)

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
                    if isNarrow {
                        Image(systemName: "wand.and.sparkles")
                    } else {
                        Label("Transform", systemImage: "wand.and.sparkles")
                    }
                }
            } else {
                Button(action: paste) {
                    if isNarrow {
                        Image(systemName: "doc.on.clipboard")
                    } else {
                        Label("Clipboard", systemImage: "doc.on.clipboard")
                    }
                }
                .help("Add clipboard to canvas")
            }

            Menu {
                if selectedCount > 0 {
                    Button("Copy", systemImage: "doc.on.doc", action: copySelected)
                    Button(
                        selectedArePrivate ? "Unmark Private" : "Mark Private",
                        systemImage: selectedArePrivate ? "lock.open" : "lock",
                        action: togglePrivacy
                    )
                    Button("Clear Selection", systemImage: "xmark.circle", action: clearSelection)
                    Button("Delete", systemImage: "trash", role: .destructive, action: deleteSelected)
                    Divider()
                } else {
                    Button("New Card", systemImage: "plus", action: addCard)
                    Divider()
                }
                Button("History", systemImage: "clock", action: openLibrary)
                Button("Settings", systemImage: "gearshape", action: openSettings)
            } label: {
                Image(systemName: "ellipsis.circle")
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
    let copyCard: (WorkspaceCard) -> Void
    let deleteCard: (WorkspaceCard) -> Void
    let duplicateCard: (WorkspaceCard) -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void
    let addDroppedContent: (SnippetDragPayload, CGPoint) -> Void

    @State private var canvasOffset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var dragState = CanvasDragState()

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
                                dragState: dragState,
                                select: { select(card) },
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
            .dropDestination(for: SnippetDragPayload.self) { items, location in
                guard let payload = items.first, !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || payload.imageData != nil else {
                    return false
                }
                let canvasPoint = CGPoint(
                    x: (location.x - canvasOffset.width) / canvasScale,
                    y: (location.y - canvasOffset.height) / canvasScale
                )
                addDroppedContent(payload, canvasPoint)
                return true
            }
            .dropDestination(for: String.self) { items, location in
                guard let text = items.first?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                    return false
                }
                let canvasPoint = CGPoint(
                    x: (location.x - canvasOffset.width) / canvasScale,
                    y: (location.y - canvasOffset.height) / canvasScale
                )
                addDroppedContent(SnippetDragPayload(text: text, imageData: nil), canvasPoint)
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

@Observable
private final class CanvasDragState {
    var selectionOffset: CGSize = .zero
}

private struct CanvasCardView: View {
    @Bindable var card: WorkspaceCard
    let canvasScale: CGFloat
    let isSelected: Bool
    let isRunning: Bool
    let selectedCardIDs: Set<UUID>
    let dragState: CanvasDragState
    let select: () -> Void
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
                if let snippet = card.snippet {
                    Image(systemName: snippet.type == .image ? "photo.on.rectangle" : "text.quote")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .snippetDraggable(snippet)
                        .help("Drag into another app")
                }
            }

            SnippetPreviewContent(snippet: card.snippet, lineLimit: 7, imageHeight: max(86, renderedHeight - 74))

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
        .offset(dragOffset != .zero ? dragOffset : (isSelected ? dragState.selectionOffset : .zero))
        .shadow(color: .black.opacity(dragOffset != .zero ? 0.22 : (isSelected ? 0.16 : 0.08)),
                radius: dragOffset != .zero ? 18 : (isSelected ? 12 : 5),
                y: dragOffset != .zero ? 12 : (isSelected ? 7 : 2))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .gesture(cardDrag)
        .contextMenu {
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
    }

    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragOffset = value.translation
                if isSelected { dragState.selectionOffset = value.translation }
            }
            .onEnded { value in
                dragState.selectionOffset = .zero
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
        VStack(spacing: 10) {
            Image(systemName: "rectangle.3.group.bubble.left")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("Empty canvas")
                .font(.headline)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
