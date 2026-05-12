import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context

    @Query(
        sort: [SortDescriptor(\Workspace.sortIndex), SortDescriptor(\Workspace.createdAt)]
    ) private var workspaces: [Workspace]

    @State private var selectedCardID: UUID?
    @State private var lastClipboardFingerprint: String?
    @State private var feedback: String?

    private var activeWorkspace: Workspace? {
        workspaces.first(where: \.isActive) ?? workspaces.first
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .task { AppBootstrap.ensureActiveWorkspace(in: context) }
        .task(id: activeWorkspace?.id) { await watchClipboard() }
        .overlay(alignment: .top) {
            if let feedback {
                FeedbackBanner(message: feedback).padding(.top, 10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: feedback != nil)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        SidebarView(
            workspaces: workspaces,
            activeWorkspace: activeWorkspace,
            onActivateWorkspace: activateWorkspace,
            onCreateWorkspace: createWorkspace,
            onPlaceClip: placeOnCanvas
        )
    }

    // MARK: - Detail (canvas)

    @ViewBuilder
    private var detail: some View {
        if let workspace = activeWorkspace {
            CanvasView(workspace: workspace, selectedID: $selectedCardID)
                .toolbar { canvasToolbar }
        } else {
            ContentUnavailableView(
                "No workspace",
                systemImage: "rectangle.3.group",
                description: Text("Create a workspace to get started.")
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var canvasToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(activeWorkspace?.name ?? "Canvas")
                .font(.headline)
        }

        ToolbarItem(placement: .primaryAction) {
            Button(action: pasteFromClipboard) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .help("Paste from clipboard (⇧⌘V)")
        }
    }

    // MARK: - Workspace management

    private func activateWorkspace(_ workspace: Workspace) {
        workspaces.forEach { $0.isActive = ($0.id == workspace.id) }
        selectedCardID = nil
    }

    private func createWorkspace() {
        workspaces.forEach { $0.isActive = false }
        let ws = Workspace(
            name: "Canvas \(workspaces.count + 1)",
            sortIndex: (workspaces.map(\.sortIndex).max() ?? -1) + 1,
            isActive: true
        )
        context.insert(ws)
        selectedCardID = nil
    }

    // MARK: - Clip placement

    private func placeOnCanvas(_ clip: Clip) {
        guard let workspace = activeWorkspace else { return }
        workspace.place(clip: clip)
        showFeedback("Placed on canvas")
    }

    // MARK: - Clipboard

    private func pasteFromClipboard() {
        guard let workspace = activeWorkspace else { return }
        guard let content = ClipboardService.readContent() else {
            showFeedback("Clipboard is empty")
            return
        }
        let clip = Clip.make(from: content, origin: .clipboard)
        context.insert(clip)
        let placement = workspace.place(clip: clip)
        selectedCardID = placement.id
        lastClipboardFingerprint = content.fingerprint
        showFeedback("Pasted")
    }

    // Watches clipboard every second. Auto-captures new content.
    private func watchClipboard() async {
        lastClipboardFingerprint = ClipboardService.readContent()?.fingerprint
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard let content = ClipboardService.readContent() else { continue }
            guard content.fingerprint != lastClipboardFingerprint else { continue }
            lastClipboardFingerprint = content.fingerprint
            guard let workspace = activeWorkspace else { continue }
            let clip = Clip.make(from: content, origin: .clipboard)
            context.insert(clip)
            workspace.place(clip: clip)
            showFeedback("Captured from clipboard")
        }
    }

    // MARK: - Feedback

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }
}
