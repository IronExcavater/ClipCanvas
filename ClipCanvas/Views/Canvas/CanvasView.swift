import SwiftUI
import SwiftData

struct CanvasView: View {
    let workspace: Workspace
    @Binding var selectedID: UUID?

    @Environment(\.modelContext) private var context
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var feedback: String?

    private var placements: [CanvasPlacement] { workspace.placements }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                dotGrid(in: geo)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedID = nil }
                    .gesture(canvasPanGesture)

                ForEach(placements) { placement in
                    if let clip = placement.clip {
                        positionedCard(placement: placement, clip: clip)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .simultaneousGesture(canvasPinchGesture)
        .overlay(alignment: .top) {
            if let feedback {
                FeedbackBanner(message: feedback).padding(.top, 10)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: feedback != nil)
    }

    // MARK: - Dot grid background

    private func dotGrid(in geo: GeometryProxy) -> some View {
        Canvas { ctx, size in
            let spacing = 28.0 * canvasScale * pinchScale
            let ox = (canvasOffset.width + dragDelta.width).truncatingRemainder(dividingBy: spacing)
            let oy = (canvasOffset.height + dragDelta.height).truncatingRemainder(dividingBy: spacing)
            var x = ox; while x < size.width + spacing { defer { x += spacing }
                var y = oy; while y < size.height + spacing { defer { y += spacing }
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(.secondary.opacity(0.22))
                    )
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Card positioning

    private func positionedCard(placement: CanvasPlacement, clip: Clip) -> some View {
        let effectiveScale = canvasScale * pinchScale
        let effectiveOffset = CGSize(
            width: canvasOffset.width + dragDelta.width,
            height: canvasOffset.height + dragDelta.height
        )
        let screenX = placement.x * effectiveScale + effectiveOffset.width
        let screenY = placement.y * effectiveScale + effectiveOffset.height

        return ClipCard(
            clip: clip,
            isSelected: selectedID == placement.id,
            onTap: { selectedID = (selectedID == placement.id) ? nil : placement.id },
            onDelete: { deletePlacement(placement) }
        )
        .frame(width: placement.width, height: placement.height)
        .gesture(cardDragGesture(for: placement))
        .position(x: screenX + placement.width / 2, y: screenY + placement.height / 2)
        .scaleEffect(effectiveScale, anchor: .topLeading)
        .frame(width: placement.width * effectiveScale, height: placement.height * effectiveScale)
    }

    // MARK: - Gestures

    private var canvasPanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                canvasOffset.width += value.translation.width
                canvasOffset.height += value.translation.height
            }
    }

    private var canvasPinchGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                canvasScale = (canvasScale * value).clamped(to: 0.2...4.0)
            }
    }

    private func cardDragGesture(for placement: CanvasPlacement) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                let scale = canvasScale * pinchScale
                placement.x += value.translation.width / scale
                placement.y += value.translation.height / scale
            }
    }

    // MARK: - Actions

    private func deletePlacement(_ placement: CanvasPlacement) {
        if selectedID == placement.id { selectedID = nil }
        context.delete(placement)
        workspace.updatedAt = Date()
    }

    private func showFeedback(_ msg: String) {
        withAnimation { feedback = msg }
        Task {
            try? await Task.sleep(for: .seconds(1.7))
            withAnimation { feedback = nil }
        }
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
