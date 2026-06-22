import SwiftUI
import SwiftData

@main
struct ClipCanvasApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #elseif canImport(AppKit)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase

    let container: ModelContainer = {
        do {
            return try AppBootstrap.makeModelContainer()
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .onOpenURL { url in
                    if let route = AppRouteService.route(from: url) {
                        AppRouteService.open(route)
                    }
                    drainPendingCanvasActions()
                }
        }
        .commands {
            ClipCanvasCommands()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            drainPendingCanvasActions()
        }
    }

    // Consumes a quick action / Siri "copy clipboard" request or Share Extension text
    // that arrived while the app wasn't running to receive the live notification.
    private func drainPendingCanvasActions() {
        if PendingCanvasActionStore.consumeCopyToCanvasRequest() {
            NotificationCenter.default.post(name: .copyToCanvasRequested, object: nil)
        }
        if let text = PendingCanvasActionStore.consumePendingSharedText() {
            NotificationCenter.default.post(name: .sharedTextReceived, object: text)
        }
    }
}
