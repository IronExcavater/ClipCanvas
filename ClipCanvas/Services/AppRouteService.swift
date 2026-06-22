import Foundation

enum AppRoute: Equatable, Hashable {
    case workspace(UUID)
    case object(UUID)
    case clip(UUID)
    case chat(UUID)
}

extension Notification.Name {
    static let clipCanvasRouteRequested = Notification.Name("clipcanvas.routeRequested")
}

enum AppRouteService {
    private(set) static var pendingRoute: AppRoute?

    static func route(from url: URL) -> AppRoute? {
        guard url.scheme == "clipcanvas", let host = url.host() else { return nil }
        guard let idText = url.pathComponents.dropFirst().first,
              let id = UUID(uuidString: idText) else { return nil }

        switch host {
        case "workspace": return .workspace(id)
        case "object": return .object(id)
        case "clip": return .clip(id)
        case "chat": return .chat(id)
        default: return nil
        }
    }

    static func open(_ route: AppRoute) {
        pendingRoute = route
        NotificationCenter.default.post(name: .clipCanvasRouteRequested, object: route)
    }

    static func consumePendingRoute(where matches: (AppRoute) -> Bool) -> AppRoute? {
        guard let route = pendingRoute, matches(route) else { return nil }
        pendingRoute = nil
        return route
    }
}
