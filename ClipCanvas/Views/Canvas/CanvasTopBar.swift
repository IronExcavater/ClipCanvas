import SwiftUI

struct CanvasTopBar: View {
    let workspaceName: String
    @Binding var isRenaming: Bool
    @Binding var renameText: String
    var renameFocused: FocusState<Bool>.Binding
    let onToggleSidebar: () -> Void
    let onBeginRename: () -> Void
    let onCommitRename: () -> Void
    let onClearAll: () -> Void
    let onArrangeAll: () -> Void
    let onFitContent: () -> Void

    @State private var confirmingClear = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSidebar) {
                Image(systemName: AppSymbol.sidebar)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(BlendedIconButtonStyle())

            Spacer()

            title
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    WorkspaceTitleBackdrop()
                }

            Spacer()

            Menu {
                Button("Rename Workspace", systemImage: "pencil", action: onBeginRename)
                Button("Fit to Cards", systemImage: "arrow.up.left.and.arrow.down.right", action: onFitContent)
                Button("Arrange Grid", systemImage: "square.grid.2x2", action: onArrangeAll)
                Divider()
                Button("Clear Workspace", systemImage: "trash", role: .destructive) {
                    confirmingClear = true
                }
            } label: {
                AppMenuIconLabel()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            CanvasTopBarFade()
                .allowsHitTesting(false)
                .ignoresSafeArea(.container, edges: .top)
                .offset(y: -118)
        }
        .alert("Clear all clips from this workspace?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive, action: onClearAll)
        } message: {
            Text("This removes every clip placement from the current canvas.")
        }
    }

    @ViewBuilder
    private var title: some View {
        if isRenaming {
            TextField("Workspace name", text: $renameText)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused(renameFocused)
                .submitLabel(.done)
                .onSubmit(onCommitRename)
                .onDisappear {
                    if isRenaming { onCommitRename() }
                }
                .frame(maxWidth: 220)
        } else {
            Text(workspaceName)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .onTapGesture(count: 2, perform: onBeginRename)
        }
    }
}

private struct CanvasTopBarFade: View {
    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(topContrast)
            .frame(height: 260)
            .mask(fadeMask)
    }

    private var fadeMask: some View {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0.00),
                .init(color: .black.opacity(0.98), location: 0.24),
                .init(color: .black.opacity(0.82), location: 0.48),
                .init(color: .black.opacity(0.44), location: 0.72),
                .init(color: .clear, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var topContrast: some View {
        LinearGradient(
            stops: [
                .init(color: Color(uiColor: .systemBackground).opacity(0.32), location: 0.00),
                .init(color: Color(uiColor: .systemBackground).opacity(0.18), location: 0.38),
                .init(color: .clear, location: 1.00),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct WorkspaceTitleBackdrop: View {
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay {
                Capsule()
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    .blur(radius: 2.5)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.8), location: 0.22),
                                .init(color: .black.opacity(0.8), location: 0.78),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
    }
}
