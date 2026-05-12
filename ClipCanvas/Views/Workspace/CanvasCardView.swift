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
        VStack(alignment: .leading, spacing: 10) {
            CanvasCardHeader(card: card)
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
        // Scale up slightly during drag — makes it feel like you're physically lifting the card.
        .scaleEffect(isDragging ? 1.04 : 1.0)
        .animation(.interactiveSpring(duration: 0.2), value: isDragging)
        .offset(dragOffset != .zero ? dragOffset : (isSelected ? dragState.selectionOffset : .zero))
        .shadow(
            color: .black.opacity(isDragging ? 0.26 : (isSelected ? 0.16 : 0.08)),
            radius: isDragging ? 22 : (isSelected ? 12 : 5),
            y: isDragging ? 14 : (isSelected ? 7 : 2)
        )
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
            .onChanged { value in resizeOffset = value.translation }
            .onEnded { value in
                card.width = clampedCardWidth(card.width + value.translation.width / canvasScale)
                card.height = clampedCardHeight(card.height + value.translation.height / canvasScale)
                card.updatedAt = Date()
                resizeOffset = .zero
            }
    }

    private func clampedCardWidth(_ width: CGFloat) -> CGFloat { min(max(170, width), 420) }
    private func clampedCardHeight(_ height: CGFloat) -> CGFloat { min(max(120, height), 360) }
}

// MARK: - Card header

private struct CanvasCardHeader: View {
    @Bindable var card: WorkspaceCard

    var body: some View {
        HStack(spacing: 8) {
            SourceGlyph(snippet: card.snippet)
            VStack(alignment: .leading, spacing: 1) {
                Text(card.snippet?.sourceTitle ?? "Card")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if let snippet = card.snippet {
                    HStack(spacing: 4) {
                        Text(snippet.sourceDetail)
                        Text("·")
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
    }
}

// MARK: - Canvas controls strip

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
            Button(action: fit) { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                .help("Fit board")
            Button(action: reset) { Image(systemName: "arrow.counterclockwise") }
                .help("Reset zoom")
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

// MARK: - Resize handle

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

// MARK: - Card edit sheet

struct CardEditSheet: View {
    @Bindable var card: WorkspaceCard
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Metadata header mirrors the card's own header so it's clear what you're editing.
                if let snippet = card.snippet {
                    HStack(spacing: 12) {
                        SourceGlyph(snippet: snippet)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.sourceTitle)
                                .font(.subheadline.weight(.semibold))
                            Text(snippet.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(typeLabel(for: snippet))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(card.color.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(card.color.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(card.color.background)
                    Divider()
                }

                TextEditor(text: $text)
                    .font(card.snippet?.type == .code ? .system(.body, design: .monospaced) : .body)
                    .padding(12)
                    .focused($editorFocused)

                Divider()

                // Footer: character count + word count
                HStack(spacing: 12) {
                    Text("\(text.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let words = text.split(whereSeparator: \.isWhitespace).count
                    if words > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("\(words) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                text = card.snippet?.text ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    editorFocused = true
                }
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
        case .text:  "Text"
        case .url:   "URL"
        case .code:  "Code"
        case .image: "Image"
        }
    }
}
