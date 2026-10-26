// by claude
import UIKit
import UniformTypeIdentifiers

/// passes links & text shared from other apps to namida, it shows nothing of its own.
/// files reach the app through its document types instead.
final class ShareViewController: UIViewController {
  private var didForward = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if didForward { return }
    didForward = true
    Task { await forwardSharedItems() }
  }

  private func forwardSharedItems() async {
    let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
    let providers = extensionItems.flatMap { $0.attachments ?? [] }
    let texts = await Self.loadTexts(providers)
    if let url = NamidaShareUrl.build(texts) {
      openApp(url)
    }
    extensionContext?.completeRequest(returningItems: nil)
  }

  /// apps sharing a link often add the same link inside a text item, links win so it isn't opened twice.
  private static func loadTexts(_ providers: [NSItemProvider]) async -> [String] {
    var links: [String] = []
    var texts: [String] = []
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
        if let url = item as? URL, !url.isFileURL {
          links.append(url.absoluteString)
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
        if let text = item as? String {
          texts.append(text)
        }
      }
    }
    return links.isEmpty ? texts : links
  }

  /// extensions have no api to open their app, the app object at the end of the responder chain can.
  private func openApp(_ url: URL) {
    var responder: UIResponder? = self
    while let current = responder {
      if let application = current as? UIApplication {
        application.open(url, options: [:], completionHandler: nil)
        return
      }
      responder = current.next
    }
  }
}
