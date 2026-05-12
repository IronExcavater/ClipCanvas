import SwiftUI

struct CanvasTopBar: View {
    let workspaceName: String
    let selectedCount: Int
    let mode: CanvasMode
    let onToggleSidebar: () -> Void
    let onExitSelectMode: () -> Void
    let onDeleteSelected: () -> Void
    let onCopySelected: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if mode == .select {
                Button("Done") { onExitSelectMode() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.accentColor)

                Spacer()

                Text(selectedCount == 0 ? "Select items" : "\(selectedCount) selected")
                    .font(.headline)

                Spacer()

                HStack(spacing: 22) {
                    Button(action: onCopySelected) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 17))
                    }
                    .disabled(selectedCount == 0)

                    Button(action: onDeleteSelected) {
                        Image(systemName: "trash")
                            .font(.system(size: 17))
                            .foregroundStyle(selectedCount > 0 ? .red : Color.secondary)
                    }
                    .disabled(selectedCount == 0)
                }
            } else {
                Button(action: onToggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(workspaceName)
                    .font(.headline)

                Spacer()

                // Placeholder to balance the sidebar button
                Color.clear.frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }
}
