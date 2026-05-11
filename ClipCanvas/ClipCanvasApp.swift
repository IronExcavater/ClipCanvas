import SwiftData
import SwiftUI

// @main marks this struct as the application entry point — Swift calls its `body`
// property to build the scene graph when the app launches.
@main
struct ClipCanvasApp: App {
    // UIApplicationDelegateAdaptor bridges UIKit's application delegate into a SwiftUI App.
    // Needed here to receive 3D Touch / long-press home-screen quick actions.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // scenePhase reports the app's current lifecycle state: active, inactive, or background.
    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    // @State on a reference type works because AppRouter is @Observable — SwiftUI tracks
    // which properties are read and only re-renders views that depend on them.
    @State private var router = AppRouter()

    init() {
        do {
            modelContainer = try AppBootstrap.makeModelContainer()
        } catch {
            // fatalError stops the app with a crash log — appropriate here because the app
            // cannot function without its data store.
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)        // injects router into the entire view hierarchy
                .onOpenURL { router.handle(url: $0) }   // handles clipcanvas:// deep links
                .onReceive(NotificationCenter.default.publisher(for: .copyToCanvasRequested)) { note in
                    // NotificationCenter is the system-wide event bus — like EventEmitter in Node.
                    // This fires when AppDelegate receives a home-screen quick action.
                    let method = note.object as? CaptureMethod ?? .quickAction
                    router.requestCopyToCanvas(method: method)
                }
        }
        // .modelContainer makes the SwiftData store available to all views via @Environment(\.modelContext).
        .modelContainer(modelContainer)
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            let context = modelContainer.mainContext
            AppBootstrap.ensureActiveWorkspace(in: context)
            ExpiryService.deleteExpired(in: context)
            // Consume any pending quick-action request that arrived while the app was backgrounded.
            if let method = PendingCanvasActionStore.consumeCopyToCanvasRequest() {
                router.requestCopyToCanvas(method: method)
            }
        }
    }
}

