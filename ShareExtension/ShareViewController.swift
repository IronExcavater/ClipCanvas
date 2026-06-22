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
        } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.data.identifier) { [weak self] result, _ in
                if let data = result as? Data,
                   let text = String(data: data, encoding: .utf8) {
                    self?.saveAndComplete(text: text)
                } else {
                    self?.saveAndComplete(text: nil)
                }
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
            guard let url = URL(string: "clipcanvas://workspace/active") else {
                self.extensionContext?.completeRequest(returningItems: [])
                return
            }
            self.openHostApp(url)
        }
    }

    private func openHostApp(_ url: URL) {
        var didComplete = false
        let completeOnce = { [weak self] in
            guard !didComplete else { return }
            didComplete = true
            self?.extensionContext?.completeRequest(returningItems: [])
        }

        extensionContext?.open(url) { _ in
            DispatchQueue.main.async(execute: completeOnce)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: completeOnce)
    }
}
