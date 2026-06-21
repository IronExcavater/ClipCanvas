import Foundation
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
typealias PlatformViewController = NSViewController
#endif

final class ShareViewController: PlatformViewController {

    #if canImport(UIKit)
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        extractAndSave()
    }
    #elseif canImport(AppKit)
    // No storyboard/nib backs this controller, so AppKit needs an explicit view.
    override func loadView() {
        view = NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        extractAndSave()
    }
    #endif

    private func extractAndSave() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            extensionContext?.completeRequest(returningItems: [])
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] result, _ in
                let urlString = (result as? URL)?.absoluteString
                self?.saveAndComplete(text: urlString)
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] result, _ in
                let text = result as? String
                self?.saveAndComplete(text: text)
            }
        } else {
            extensionContext?.completeRequest(returningItems: [])
        }
    }

    private func saveAndComplete(text: String?) {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            PendingTextStore.savePendingText(trimmed)
        }
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [])
        }
    }
}
