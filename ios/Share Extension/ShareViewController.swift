import Foundation

// The collector is Foundation-only so callback ordering can be regression
// tested without launching a share sheet or linking the Flutter engine.
struct SharedLocationPayload: Equatable {
    let text: String
    let isURL: Bool
}

enum SharedLocationCollector {
    typealias Loader = (@escaping (SharedLocationPayload?) -> Void) -> Void

    /// NSItemProvider callbacks are unordered. Persist only once every
    /// attachment has finished, retaining the order from the share sheet.
    static func collect(
        _ loaders: [Loader],
        completion: @escaping ([SharedLocationPayload]) -> Void
    ) {
        let group = DispatchGroup()
        var values = [SharedLocationPayload?](repeating: nil, count: loaders.count)
        for (index, load) in loaders.enumerated() {
            group.enter()
            load { value in
                DispatchQueue.main.async {
                    values[index] = value
                    group.leave()
                }
            }
        }
        group.notify(queue: .main) {
            var seen = Set<String>()
            completion(values.compactMap { value in
                guard let value = value else { return nil }
                let text = value.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, seen.insert(text).inserted else { return nil }
                return SharedLocationPayload(text: text, isURL: value.isURL)
            })
        }
    }

    /// A provider can expose both a place caption and its URL. Read the URL
    /// first, and only use text if the URL representation cannot be loaded.
    static func preferred(
        _ loaders: [Loader],
        completion: @escaping (SharedLocationPayload?) -> Void
    ) {
        guard let first = loaders.first else {
            completion(nil)
            return
        }
        first { value in
            if let value = value,
               !value.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                completion(value)
            } else {
                preferred(Array(loaders.dropFirst()), completion: completion)
            }
        }
    }
}

#if !SHARE_PAYLOAD_TEST
import UIKit
import receive_sharing_intent

/// Collects Maps links locally, then uses the plugin's existing App Group
/// payload and host-app handoff. The plugin's default controller saves when
/// the last attachment *index* completes, which can discard a slower URL.
final class ShareViewController: UIViewController {
    private var hasStarted = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasStarted else { return }
        hasStarted = true

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        var loaders = [SharedLocationCollector.Loader]()
        for item in items {
            let providers = (item.attachments ?? []).filter {
                $0.hasItemConformingToTypeIdentifier("public.url") ||
                $0.hasItemConformingToTypeIdentifier("public.text")
            }
            for provider in providers {
                loaders.append { completion in
                    Self.load(provider, completion: completion)
                }
            }
            // Some sources provide text directly on the extension item.
            if providers.isEmpty, let text = item.attributedContentText?.string {
                loaders.append { completion in
                    completion(SharedLocationPayload(text: text, isURL: false))
                }
            }
        }
        SharedLocationCollector.collect(loaders) { [weak self] payload in
            self?.saveAndOpen(payload)
        }
    }

    private static func load(
        _ provider: NSItemProvider,
        completion: @escaping (SharedLocationPayload?) -> Void
    ) {
        let types = ["public.url", "public.utf8-plain-text", "public.text"].filter {
            provider.hasItemConformingToTypeIdentifier($0)
        }
        let loaders: [SharedLocationCollector.Loader] = types.map { type in
            { complete in
                provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                    guard error == nil else {
                        complete(nil)
                        return
                    }
                    let text: String?
                    if let url = item as? URL {
                        text = url.isFileURL ? nil : url.absoluteString
                    } else if let string = item as? String {
                        text = string
                    } else if let attributed = item as? NSAttributedString {
                        text = attributed.string
                    } else if let data = item as? Data {
                        text = String(data: data, encoding: .utf8)
                    } else {
                        text = nil
                    }
                    guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !value.isEmpty else {
                        complete(nil)
                        return
                    }
                    if type == "public.url" {
                        guard let url = URL(string: value),
                              url.scheme != nil, !url.isFileURL else {
                            complete(nil)
                            return
                        }
                    }
                    complete(SharedLocationPayload(text: value, isURL: type == "public.url"))
                }
            }
        }
        SharedLocationCollector.preferred(loaders, completion: completion)
    }

    private func saveAndOpen(_ payload: [SharedLocationPayload]) {
        guard !payload.isEmpty,
              let extensionID = Bundle.main.bundleIdentifier,
              let separator = extensionID.lastIndex(of: ".") else {
            showError()
            return
        }
        let hostID = String(extensionID[..<separator])
        let configuredGroup = Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String
        let groupID = configuredGroup.flatMap { $0.isEmpty ? nil : $0 } ?? "group.\(hostID)"
        guard let defaults = UserDefaults(suiteName: groupID),
              let url = URL(string: "\(kSchemePrefix)-\(hostID):share") else {
            showError()
            return
        }
        do {
            let files = payload.map {
                SharedMediaFile(
                    path: $0.text,
                    mimeType: $0.isURL ? nil : "text/plain",
                    type: $0.isURL ? .url : .text
                )
            }
            defaults.set(try JSONEncoder().encode(files), forKey: kUserDefaultsKey)
            defaults.removeObject(forKey: kUserDefaultsMessageKey)
            // The host immediately reads from a separate process.
            defaults.synchronize()
            openHost(url)
        } catch {
            showError()
        }
    }

    private func openHost(_ url: URL) {
        // Preserve the host-opening mechanism used by receive_sharing_intent,
        // including the iOS 18+ path, after the complete payload is saved.
        var responder: UIResponder? = self
        while let current = responder {
            if #available(iOS 18.0, *) {
                if let application = current as? UIApplication {
                    application.open(url, options: [:]) { [weak self] opened in
                        self?.finishOpening(opened)
                    }
                    return
                }
            } else {
                let selector = sel_registerName("openURL:")
                if current.responds(to: selector) {
                    current.perform(selector, with: url)
                    finishOpening(true)
                    return
                }
            }
            responder = current.next
        }
        extensionContext?.open(url) { [weak self] opened in
            self?.finishOpening(opened)
        }
    }

    private func finishOpening(_ opened: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if opened {
                self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            } else {
                self.showError()
            }
        }
    }

    private func showError() {
        let alert = UIAlertController(
            title: "Laffah",
            message: NSLocalizedString(
                "Couldn't read this shared location. Try sharing it again from Maps.",
                comment: "Map share import failed"
            ),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Dismiss"), style: .default) {
            [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        })
        present(alert, animated: true)
    }
}
#endif
