import CoreGraphics

enum WorkspaceShellLayout: Equatable {
    case overlayDrawer
    case split
    case splitWithInspector

    var prefersInspector: Bool {
        self == .splitWithInspector
    }

    static func resolve(
        width: CGFloat,
        isCompactWidth: Bool,
        prefersDesktopLayout: Bool
    ) -> WorkspaceShellLayout {
        if prefersDesktopLayout || width >= 980 {
            return .splitWithInspector
        }

        if isCompactWidth && width < 700 {
            return .overlayDrawer
        }

        return .split
    }
}
