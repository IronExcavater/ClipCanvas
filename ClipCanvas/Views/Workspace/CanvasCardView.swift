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
    @State private var isExpanded = false

    private var renderedWidth: CGFloat {
        clampedCardWidth(card.width + resizeOffset.width / canvasScale)
    }
    private var renderedHeight: CGFloat {
        clampedCardHeight(card.height + resizeOffset.height / canvasScale)
    }
    private var displayHeight: CGFloat {
        isExpanded ? min(renderedHeight * 2.5, 520) : renderedHeight
    }

    // True when this card or any grouped selection is actively being dragged
    private var isLiftedForDrag: Bool {
        isDragging || (isSelected && dragState.isDraggingActive)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            noteBody

            if isSelected {
                ResizeHandle()
                    .gesture(resizeDrag)
            }

            if isRunning {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay { ProgressView() }
            }
        }
        .frame(width: renderedWidth, height: displayHeight)
        .background(card.color.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.black.opacity(0.07),
                    lineWidth: isSelected ? 2.5 : 1
                )
        }
        .shadow(
            color: .black.opacity(isLiftedForDrag ? 0.22 : (isSelected ? 0.14 : 0.10)),
            radius: isLiftedForDrag ? 20 : (isSelected ? 10 : 6),
            y: isLiftedForDrag ? 12 : (isSelected ? 6 : 4)
        )
        .scaleEffect(isLiftedForDrag ? 1.04 : 1.0)
        .animation(.interactiveSpring(duration: 0.2), value: isLiftedForDrag)
        .animation(.spring(duration: 0.28), value: isExpanded)
        .offset(dragOffset != .zero ? dragOffset : (isSelected ? dragState.selectionOffset : .zero))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(.spring(duration: 0.28)) { isExpanded.toggle() }
        }
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

    // MARK: Note body

    @ViewBuilder
    private var noteBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let snippet = card.snippet, snippet.type == .image {
                    SnippetPreviewContent(snippet: snippet, lineLimit: 12, imageHeight: max(80, displayHeight - 54))
                } else {
                    Text(card.snippet?.preview ?? "Empty note")
                        .font(card.snippet?.type == .code
                              ? .system(.callout, design: .monospaced)
                              : .body)
                        .foregroundStyle((card.snippet?.text.isEmpty ?? true) ? .secondary : .primary)
                        .lineLimit(isExpanded ? nil : 12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .frame(maxHeight: .infinity, alignment: .topLeading)

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
                if isExpanded {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
                    if isSelected { dragState.isDraggingActive = true }
                }
                dragOffset = value.translation
                if isSelected { dragState.selectionOffset = value.translation }
            }
            .onEnded { value in
                withAnimation(.interactiveSpring(duration: 0.2)) { isDragging = false }
                dragState.selectionOffset = .zero
                dragState.isDraggingActive = false
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
                if isExpanded { isExpanded = false }
            }
    }

    private func clampedCardWidth(_ w: CGFloat)  -> CGFloat { min(max(160, w), 420) }
    private func clampedCardHeight(_ h: CGFloat) -> CGFloat { min(max(120, h), 360) }
}

// MARK: - Resize handle (corner grip lines)

private struct ResizeHandle: View {
    var body: some View {
        Canvas { ctx, size in
            let count = 3
            let spacing: CGFloat = 5
            let lineWidth: CGFloat = 1.5
            for i in 0..<count {
                let offset = CGFloat(i) * spacing
                var path = Path()
                path.move(to: CGPoint(x: size.width - offset - spacing, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height - offset - spacing))
                ctx.stroke(path, with: .color(.secondary.opacity(0.5)), lineWidth: lineWidth)
            }
        }
        .frame(width: 22, height: 22)
        .padding(6)
        .contentShape(Rectangle())
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
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Start writing…")
                                .foregroundStyle(.tertiary)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }

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
