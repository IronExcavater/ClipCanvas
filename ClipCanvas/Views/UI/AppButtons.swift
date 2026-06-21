import SwiftUI

struct BlendedIconButtonStyle: ButtonStyle {
    let size: CGFloat

    init(size: CGFloat = 46) {
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .modifier(BlendedIconButtonBackground(isPressed: configuration.isPressed, size: size))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Circle())
            .animation(.spring(response: 0.18, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private struct BlendedIconButtonBackground: ViewModifier {
    let isPressed: Bool
    let size: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        content
            .background {
                AppGlassSurface(
                    shape: .circle,
                    fallback: .color(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground)),
                    interactive: true,
                    stroke: Color.primary.opacity(0.06)
                )
            }
            .shadow(color: .black.opacity(isPressed ? 0.08 : 0.14), radius: isPressed ? 5 : 10, y: isPressed ? 2 : 5)
    }
}

struct AppCircleIconLabel: View {
    let systemImage: String
    var size: CGFloat = 46
    var symbolSize: CGFloat = 18

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .contentShape(Circle())
    }
}

struct AppToolbarCircleLabel: View {
    let systemImage: String
    var size: CGFloat = 40
    var symbolSize: CGFloat = 16

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size, height: size)
            .background {
                AppGlassSurface(
                    shape: .circle,
                    fallback: .color(Color.adaptive(light: .white, dark: PlatformColor.secondarySystemBackground))
                )
            }
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
            .contentShape(Circle())
    }
}

struct AppToolbarCircleButton: View {
    let systemImage: String
    var size: CGFloat = 40
    var symbolSize: CGFloat = 16
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            AppToolbarCircleLabel(systemImage: systemImage, size: size, symbolSize: symbolSize)
        }
        .buttonStyle(.plain)
    }
}

struct AppSwipeIconButton: View {
    let systemImage: String
    var tint: Color?
    var role: ButtonRole?
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
        }
        .if(tint != nil) { view in
            view.tint(tint ?? .accentColor)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

/// A small system icon in a coloured circle — used consistently in list rows throughout the app.
struct AppIconBadge: View {
    let systemImage: String
    var size: CGFloat = 22
    var iconSize: CGFloat = 12
    let color: Color
    var foreground: Color = .white

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

struct AppDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 4)
    }
}

extension View {
    @ViewBuilder
    func appInlineNavigationTitleDisplayMode() -> some View {
        #if canImport(UIKit)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appScrollDismissesKeyboardInteractively() -> some View {
        #if canImport(UIKit)
        self.scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appSheetPresentationDetents() -> some View {
        #if canImport(UIKit)
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appSearchable(text: Binding<String>, isPresented: Binding<Bool>, prompt: String) -> some View {
        #if canImport(UIKit)
        self.searchable(
            text: text,
            isPresented: isPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(prompt)
        )
        #else
        self.searchable(text: text, prompt: Text(prompt))
        #endif
    }

    @ViewBuilder
    func appListSectionSpacingCompact() -> some View {
        #if canImport(UIKit)
        self.listSectionSpacing(.compact)
        #else
        self
        #endif
    }

    @ViewBuilder
    func appSidebarListStyle() -> some View {
        #if os(macOS)
        self
            .listStyle(.sidebar)
            .contentMargins(.horizontal, 14, for: .scrollContent)
            .appListRowSpacing(6)
        #else
        self
            .listStyle(.plain)
            .contentMargins(.horizontal, 14, for: .scrollContent)
            .appListRowSpacing(6)
        #endif
    }

    @ViewBuilder
    func appHideNavigationBarIfAvailable() -> some View {
        #if canImport(UIKit)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    func appListCard(tint: Color, opacity: Double = 0.10) -> some View {
        AppListItemContainer(tint: tint, opacity: opacity) {
            self
        }
    }

    func appListItemRowInsets(horizontal: CGFloat = 0, vertical: CGFloat = 0) -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: horizontal, bottom: 0, trailing: horizontal))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func appEmptyStateRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 20, leading: 18, bottom: 20, trailing: 18))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    /// Wraps the view in a glass panel background (iOS 26 glass or regularMaterial fallback).
    func glassPanel(cornerRadius: CGFloat = 26, shadow: Bool = true, interactive: Bool = false) -> some View {
        self
            .background {
                AppGlassSurface(shape: .rect(cornerRadius: cornerRadius), interactive: interactive)
            }
            .shadow(color: .black.opacity(shadow ? 0.16 : 0), radius: shadow ? 22 : 0, y: shadow ? 10 : 0)
    }

    /// Wraps the view in a capsule glass background (iOS 26 glass or regularMaterial fallback).
    func glassCapsule(shadow: Bool = true, interactive: Bool = false) -> some View {
        self
            .background {
                AppGlassSurface(shape: .capsule, interactive: interactive)
            }
            .shadow(color: .black.opacity(shadow ? 0.18 : 0), radius: shadow ? 20 : 0, y: shadow ? 8 : 0)
    }
}
