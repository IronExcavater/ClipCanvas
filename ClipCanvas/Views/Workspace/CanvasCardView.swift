import SwiftData
import SwiftUI

struct CanvasCardView: View {
    @Bindable var card: WorkspaceCard
    let canvasScale: CGFloat
    let isSelected: Bool
    let isRunning: Bool
    let selectedCardIDs: Set<UUID>
    let dragState: CanvasDragState
    let select: () -> Void
    let ask: () -> Void
    let edit: () -> Void
    let copy: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero
    @State private var isDragging = false

    private var renderedWidth: CGFloat {
        clampedCardWidth(card.width + resizeOffset.width / canvasScale)
    }
    private var renderedHeight: CGFloat {
        clampedCardHeight(card.height + resizeOffset.height / canvasScale)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            noteBody

            if isSelected {
                ResizeHandle()
                    .padding(5)
                    .gesture(resizeDrag)
            }

            if isRunning {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: renderedWidth, height: renderedHeight)
        // Sticky-note styling: solid color, continuous radius, natural shadow
        .background(card.color.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.black.opacity(0.07),
                    lineWidth: isSelected ? 2.5 : 1
                )
        }
        .shadow(
            color: .black.opacity(isDragging ? 0.22 : (isSelected ? 0.14 : 0.10)),
            radius: isDragging ? 20 : (isSelected ? 10 : 6),
            y: isDragging ? 12 : (isSelected ? 6 : 4)
        )
        // Lift effect when dragging
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .animation(.interactiveSpring(duration: 0.2), value: isDragging)
        .offset(dragOffset != .zero ? dragOffset : (isSelected ? dragState.selectionOffset : .zero))
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .gesture(cardDrag)
        .contextMenu {
            Button("Ask About This", systemImage: "sparkles", action: ask)
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

    // MARK: Note body layout

    @ViewBuilder
    private var noteBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content fills the bulk of the note
            Group {
                if let snippet = card.snippet, snippet.type == .image {
                    SnippetPreviewContent(snippet: snippet, lineLimit: 9, imageHeight: max(80, renderedHeight - 54))
                } else {
                    Text(card.snippet?.preview ?? "Empty note")
                        .font(card.snippet?.type == .code
                              ? .system(.callout, design: .monospaced)
                              : .body)
                        .foregroundStyle((card.snippet?.text.isEmpty ?? true) ? .secondary : .primary)
                        .lineLimit(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            // Footer: source icon · relative time
            HStack(spacing: 5) {
                if let snippet = card.snippet {
                    Image(systemName: snippet.sourceIcon)
                        .font(.caption2)
                    Text(snippet.createdAt, style: .relative)
                        .font(.caption2)
                }
                Spacer(minLength: 0)
                if card.transformRun != nil {
                    Image(systemName: "wand.and.sparkles")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.7))
                }
            }
            .foregroundStyle(.primary.opacity(0.38))
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
    }

    // MARK: Gestures

    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if !isDragging {
                    withAnimation(.interactiveSpring(duration: 0.15)) { isDragging = true }
                }
                dragOffset = value.translation
                if isSelected { dragState.selectionOffset = value.translation }
            }
            .onEnded { value in
                withAnimation(.interactiveSpring(duration: 0.2)) { isDragging = false }
                dragState.selectionOffset = .zero
                let ids = isSelected ? selectedCardIDs : [card.id]
                if ids.count > 1 {
                    moveCards(ids, value.translation, canvasScale)
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
            .onChanged { value in resizeOffset = value.translation }
            .onEnded { value in
                card.width  = clampedCardWidth(card.width   + value.translation.width  / canvasScale)
                card.height = clampedCardHeight(card.height + value.translation.height / canvasScale)
                card.updatedAt = Date()
                resizeOffset = .zero
            }
    }

    private func clampedCardWidth(_ w: CGFloat)  -> CGFloat { min(max(160, w), 420) }
    private func clampedCardHeight(_ h: CGFloat) -> CGFloat { min(max(120, h), 360) }
}

// MARK: - Zoom / reset control strip

struct CanvasControlStrip: View {
    let scale: CGFloat
    let canZoomOut: Bool
    let canZoomIn: Bool
    let zoomOut: () -> Void
    let zoomIn: () -> Void
    let fit: () -> Void
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: zoomOut) { Image(systemName: "minus.magnifyingglass") }
                .disabled(!canZoomOut)
                .help("Zoom out")
            Text("\(Int(scale * 100))%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .frame(width: 48)
            Button(action: zoomIn) { Image(systemName: "plus.magnifyingglass") }
                .disabled(!canZoomIn)
                .help("Zoom in")
            Divider().frame(height: 22)
            Button(action: fit)   { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .help("Fit board")
            Button(action: reset) { Image(systemName: "arrow.counterclockwise") }
                .help("Reset view")
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.08))
        }
    }
}

// MARK: - Resize handle

private struct ResizeHandle: View {
    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }
}

// MARK: - Card edit sheet

struct CardEditSheet: View {
    @Bindable var card: WorkspaceCard
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let snippet = card.snippet {
                    HStack(spacing: 12) {
                        SourceGlyph(snippet: snippet)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.sourceTitle).font(.subheadline.weight(.semibold))
                            Text(snippet.createdAt, style: .relative)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(typeLabel(for: snippet))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(card.color.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(card.color.accent)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(card.color.background)
                    Divider()
                }

                TextEditor(text: $text)
                    .font(card.snippet?.type == .code ? .system(.body, design: .monospaced) : .body)
                    .padding(12)
                    .focused($editorFocused)

                Divider()

                HStack(spacing: 10) {
                    Text("\(text.count) chars")
                    let words = text.split(whereSeparator: \.isWhitespace).count
                    if words > 0 { Text("·").foregroundStyle(.tertiary); Text("\(words) words") }
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).fontWeight(.semibold)
                }
            }
            .onAppear {
                text = card.snippet?.text ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { editorFocused = true }
            }
        }
    }

    private func save() {
        card.snippet?.text = text
        card.updatedAt = Date()
        dismiss()
    }

    private func typeLabel(for snippet: Snippet) -> String {
        switch snippet.type {
        case .text: "Text"; case .url: "URL"; case .code: "Code"; case .image: "Image"
        }
    }
}
