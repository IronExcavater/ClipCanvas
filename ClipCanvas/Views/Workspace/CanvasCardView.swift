import SwiftData
import SwiftUI

struct CanvasCardView: View {
    // @Bindable wraps an @Observable model class and creates two-way Bindings from its properties.
    // Unlike @Binding (which connects two views), @Bindable connects a view to an observable model.
    @Bindable var card: WorkspaceCard
    let canvasScale: CGFloat
    let isSelected: Bool
    let isRunning: Bool
    let selectedCardIDs: Set<UUID>
    let dragState: CanvasDragState  // shared object so all selected cards move together during drag
    let select: () -> Void
    let ask: () -> Void
    let edit: () -> Void
    let copy: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void
    let moveCards: (Set<UUID>, CGSize, CGFloat) -> Void

    // @State for visual offset during drag/resize — not persisted, resets when the gesture ends.
    @State private var dragOffset: CGSize = .zero
    @State private var resizeOffset: CGSize = .zero

    // Compute the display size including any in-progress resize gesture delta.
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
            // Top colour stripe acts as a visual accent bar.
            Rectangle()
                .fill(card.color.accent)
                .frame(height: 3)
                .clipShape(.rect(topLeadingRadius: 8, topTrailingRadius: 8))
        }
        .overlay {
            // Selection ring — thicker and uses accent colour when selected.
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
                // Semi-transparent overlay with a spinner while the transform runs.
                RoundedRectangle(cornerRadius: 8)
                    .fill(.regularMaterial)
                ProgressView()
            }
        }
        // Apply drag offset: use this card's own dragOffset if dragging solo;
        // otherwise follow the shared selectionOffset when part of a multi-select drag.
        .offset(dragOffset != .zero ? dragOffset : (isSelected ? dragState.selectionOffset : .zero))
        .shadow(color: .black.opacity(dragOffset != .zero ? 0.22 : (isSelected ? 0.16 : 0.08)),
                radius: dragOffset != .zero ? 18 : (isSelected ? 12 : 5),
                y: dragOffset != .zero ? 12 : (isSelected ? 7 : 2))
        // .contentShape makes the entire frame tappable, including any transparent areas.
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
    }

    // DragGesture tracks a finger or Apple Pencil drag across the screen.
    private var cardDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                dragOffset = value.translation
                // Broadcast to all selected cards so they preview the same movement.
                if isSelected { dragState.selectionOffset = value.translation }
            }
            .onEnded { value in
                dragState.selectionOffset = .zero
                let movingIDs = isSelected ? selectedCardIDs : [card.id]
                if movingIDs.count > 1 {
                    // Multi-card move — let WorkspaceView update all model coordinates.
                    moveCards(movingIDs, value.translation, canvasScale)
                } else {
                    // Single card — update model coordinates directly.
                    // Divide by canvasScale to convert screen pixels → canvas coordinates.
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
                card.width = clampedCardWidth(card.width + value.translation.width / canvasScale)
                card.height = clampedCardHeight(card.height + value.translation.height / canvasScale)
                card.updatedAt = Date()
                resizeOffset = .zero
            }
    }

    private func clampedCardWidth(_ width: CGFloat) -> CGFloat { min(max(170, width), 420) }
    private func clampedCardHeight(_ height: CGFloat) -> CGFloat { min(max(120, height), 360) }
}

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
                        Text("-")
                        Text(snippet.createdAt, style: .relative)    // e.g. "3 min ago"
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
                    .snippetDraggable(snippet)  // makes this icon a drag handle for other apps
                    .help("Drag into another app")
            }
        }
    }
}

// Zoom and reset controls shown at the bottom-right of the canvas.
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
                .monospacedDigit()  // fixed-width digits prevent layout shifts as the number changes
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

struct CardEditSheet: View {
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
                // .onAppear runs once when the view first appears — used here to seed the
                // TextEditor with the card's current text before the user starts editing.
                .onAppear { text = card.snippet?.text ?? "" }
        }
    }

    private func save() {
        card.snippet?.text = text
        card.updatedAt = Date()
        dismiss()
    }
}
