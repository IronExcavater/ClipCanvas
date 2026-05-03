import SwiftData
import SwiftUI

struct WorkspaceView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Workspace> { !$0.isArchived },
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]

    @State private var selectedCardIDs = Set<UUID>()
    @State private var editingCard: WorkspaceCard?
    @State private var showChatPanel = false
    @State private var showWorkspacePicker = false
    @State private var showLibrary = false
    @State private var showSettings = false
    @State private var feedback: String?
    @State private var runningTransforms = Set<UUID>()
    @State private var chatContextCardIDs = Set<UUID>()
    @State private var droppedChatContext: [String] = []

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
        NavigationStack {
            ZStack {
                CanvasSurface(
                    workspace: activeWorkspace,
                    selectedCardIDs: $selectedCardIDs,
                    editingCard: $editingCard,
                    runningTransforms: runningTransforms,
                    openChatForCard: openChat(for:),
                    copyCard: copyCard,
                    deleteCard: deleteCard,
                    duplicateCard: duplicateCard
                )

                if showChatPanel, let workspace = activeWorkspace {
                    HStack {
                        Spacer(minLength: 0)
                        WorkspaceChatPanel(
                            workspace: workspace,
                            contextCards: chatContextCards,
                            extraContext: $droppedChatContext,
                            insertReply: insertChatReply,
                            close: { showChatPanel = false }
                        )
                        .frame(maxWidth: 390)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }

                if let feedback {
                    VStack {
                        Text(feedback)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.regularMaterial, in: Capsule())
                            .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle(activeWorkspace?.name ?? "Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Button { showWorkspacePicker = true } label: {
                            Image(systemName: "square.stack.3d.up")
                        }
                        Button { showLibrary = true } label: {
                            Image(systemName: "tray.full")
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    CanvasToolbar(
                        hasSelection: !selectedCardIDs.isEmpty,
                        transform: runTransform,
                        paste: { pasteToCanvas(method: .manualPaste) },
                        addCard: addBlankCard,
                        chat: openChatForSelection,
                        copySelected: copySelectedCards,
                        deleteSelected: deleteSelectedCards,
                        clearSelection: { selectedCardIDs.removeAll() }
                    )
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Text(activeWorkspace.map { "\($0.cards.count) card\($0.cards.count == 1 ? "" : "s")" } ?? "No workspace")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(item: $editingCard) { card in
                CardEditSheet(card: card)
            }
            .sheet(isPresented: $showWorkspacePicker) {
                WorkspacesView()
            }
            .sheet(isPresented: $showLibrary) {
                LibraryView()
                    .presentationDetents([.medium, .large])
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
            .animation(.spring(duration: 0.25), value: feedback)
        }
    }

    private func consumePendingRoute(_ route: AppRoute?) {
        if case .workspace(let id) = route {
            activateWorkspace(id: id)
            router.pendingRoute = nil
            return
        }
        guard route == .copyToCanvas else { return }
        pasteToCanvas(method: router.pendingPasteMethod ?? .quickAction)
        router.pendingRoute = nil
        router.pendingPasteMethod = nil
    }

    private func activateWorkspace(id: UUID) {
        guard let target = workspaces.first(where: { $0.id == id }) else { return }
        for workspace in workspaces {
            workspace.isActive = workspace.id == target.id
            workspace.updatedAt = Date()
        }
        selectedCardIDs.removeAll()
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
        insertCard(text: text, method: method, workspace: workspace)
        showFeedback("Copied to canvas")
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
        offset: Double = 0
    ) {
        let snippet = Snippet.make(from: text, capturedBy: method)
        modelContext.insert(snippet)
        let index = Double(workspace.cards.count)
        let card = WorkspaceCard(
            snippet: snippet,
            x: 140 + offset + (index.truncatingRemainder(dividingBy: 4) * 32),
            y: 160 + offset + (index.truncatingRemainder(dividingBy: 6) * 28)
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
                    x: (anchor?.x ?? 160) + 260,
                    y: (anchor?.y ?? 160) + 30,
                    width: 240,
                    height: 160,
                    color: .green
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
        guard let text = card.snippet?.text, !text.isEmpty else { return }
        PasteboardService.writeString(text)
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
            x: card.x + 24,
            y: card.y + 24,
            width: card.width,
            height: card.height,
            color: card.color
        )
        copy.workspace = workspace
        workspace.cards.append(copy)
        selectedCardIDs = [copy.id]
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

    private func showFeedback(_ message: String) {
        withAnimation { feedback = message }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
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
                                toggleSelection: { toggleSelection(card) },
                                ask: { openChatForCard(card) },
                                edit: { editingCard = card },
                                copy: { copyCard(card) },
                                duplicate: { duplicateCard(card) },
                                delete: { deleteCard(card) }
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
                    reset: resetView
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(18)
            }
            .clipped()
            .simultaneousGesture(zoomGesture(proxy: proxy))
        }
        .background(Color(.systemGroupedBackground))
    }

    private func toggleSelection(_ card: WorkspaceCard) {
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
                let nextScale = min(max(baseScale * value, 0.4), 2.8)
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
        let nextScale = min(max(canvasScale * factor, 0.4), 2.8)
        withAnimation(.snappy(duration: 0.16)) {
            canvasScale = nextScale
            baseScale = nextScale
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
    let toggleSelection: () -> Void
    let ask: () -> Void
    let edit: () -> Void
    let copy: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero

    private var renderedWidth: CGFloat {
        min(max(160, card.width + resizeOffset.width / canvasScale), 380)
    }

    private var renderedHeight: CGFloat {
        min(max(120, card.height + resizeOffset.height / canvasScale), 340)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: card.snippet?.type.icon ?? "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(card.snippet?.captureMethod.label ?? "Card")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if card.transformRun != nil {
                    Image(systemName: "wand.and.sparkles")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Text(displayText)
                .font(.body)
                .foregroundStyle(displayTextIsPlaceholder ? .secondary : .primary)
                .lineLimit(6)
                .textSelection(.enabled)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: renderedWidth, height: renderedHeight, alignment: .topLeading)
        .background(card.color.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
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
        .contentShape(Rectangle())
        .onTapGesture(perform: toggleSelection)
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
                card.x += value.translation.width / canvasScale
                card.y += value.translation.height / canvasScale
                card.updatedAt = Date()
                dragOffset = .zero
            }
    }

    private var resizeDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                resizeOffset = value.translation
            }
            .onEnded { value in
                card.width = min(max(160, card.width + value.translation.width / canvasScale), 380)
                card.height = min(max(120, card.height + value.translation.height / canvasScale), 340)
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

private struct CanvasToolbar: View {
    let hasSelection: Bool
    let transform: (TransformKind) -> Void
    let paste: () -> Void
    let addCard: () -> Void
    let chat: () -> Void
    let copySelected: () -> Void
    let deleteSelected: () -> Void
    let clearSelection: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if hasSelection {
                Menu {
                    ForEach(TransformKind.allCases, id: \.self) { kind in
                        Button(kind.label) { transform(kind) }
                    }
                } label: {
                    Image(systemName: "wand.and.sparkles")
                }
                Button(action: chat) {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                Button(action: copySelected) {
                    Image(systemName: "doc.on.doc")
                }
                Button(role: .destructive, action: deleteSelected) {
                    Image(systemName: "trash")
                }
                Button("Done", action: clearSelection)
            } else {
                Button(action: paste) {
                    Image(systemName: "doc.on.clipboard")
                }
                Button(action: addCard) {
                    Image(systemName: "plus")
                }
            }
        }
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
                .navigationBarTitleDisplayMode(.inline)
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
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 34))
                .foregroundStyle(.tertiary)
            Text("Paste to start the canvas")
                .font(.headline)
            Text("Use the clipboard button or the Home Screen quick action.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
