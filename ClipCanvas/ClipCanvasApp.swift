import SwiftData
import SwiftUI

@main
struct ClipCanvasApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    @State private var router = AppRouter()

    init() {
        do {
            modelContainer = try AppBootstrap.makeModelContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { router.handle(url: $0) }
                .onReceive(NotificationCenter.default.publisher(for: .copyToCanvasRequested)) { note in
                    let method = note.object as? CaptureMethod ?? .quickAction
                    router.requestCopyToCanvas(method: method)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            let context = modelContainer.mainContext
            AppBootstrap.ensureActiveWorkspace(in: context)
            ExpiryService.deleteExpired(in: context)
            if let method = PendingCanvasActionStore.consumeCopyToCanvasRequest() {
                router.requestCopyToCanvas(method: method)
            }
        }
    }
}
