import Flutter
import UIKit
import UniformTypeIdentifiers

/// Hosts the Flutter view and the app's one native side-channel.
///
/// The channel (`laffeh/app`) exists on Android for opening WhatsApp; here
/// it carries a single method, `pickCsvFile`. A dispatcher's round arrives
/// as a spreadsheet far more often than as twenty pasted links, and reading
/// one means letting the driver reach into Files / iCloud / Drive.
///
/// It is hand-rolled rather than a plugin on purpose. `file_picker` was in
/// this app once and was removed for the App Store build: its pods link the
/// photo library and the whole permission surface, which is the ITMS-90683
/// rejection class, for a feature that needs neither. `UIDocumentPicker`
/// asks for no permission at all — the user picking the file *is* the
/// grant — so this is both smaller and quieter than the dependency.
///
/// The channel is registered here rather than in `AppDelegate` because the
/// app runs on a scene: the `FlutterViewController` does not exist until
/// the scene connects, and a binary messenger read any earlier is nil.
class SceneDelegate: FlutterSceneDelegate {
  /// Held for the life of the scene: the picker is a delegate, and UIKit
  /// does not retain those.
  private var csvPicker: CsvFilePicker?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController
    else { return }

    let picker = CsvFilePicker(presenter: controller)
    csvPicker = picker

    let channel = FlutterMethodChannel(
      name: "laffeh/app",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pickCsvFile":
        picker.pick(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Opens the system document picker and hands Dart back the file's text.
///
/// Returns `nil` for "the user backed out", which Dart treats as a
/// non-event — cancelling a file picker is not an error and must not
/// produce a message.
final class CsvFilePicker: NSObject, UIDocumentPickerDelegate {
  private weak var presenter: UIViewController?
  private var pending: FlutterResult?

  init(presenter: UIViewController) {
    self.presenter = presenter
  }

  func pick(result: @escaping FlutterResult) {
    // One at a time. A second call while a picker is up is a double tap,
    // not a second import.
    guard pending == nil, let presenter = presenter else {
      result(nil)
      return
    }
    pending = result

    // `commaSeparatedText` alone hides files a spreadsheet exported with a
    // generic type, and plenty of phones type a .csv as plain text.
    var types: [UTType] = [.commaSeparatedText, .plainText, .text]
    if let csv = UTType(filenameExtension: "csv") {
      types.append(csv)
    }
    // asCopy: the file lands in our own tmp directory, so there is no
    // security-scoped bookmark to open, close, or leak.
    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: types,
      asCopy: true
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let done = pending else { return }
    pending = nil
    guard let url = urls.first else {
      done(nil)
      return
    }
    do {
      let data = try Data(contentsOf: url)
      guard let text = Self.decode(data) else {
        done(
          FlutterError(
            code: "unreadable",
            message: "The file is not text in any encoding we read",
            details: nil
          )
        )
        return
      }
      done(text)
    } catch {
      done(
        FlutterError(
          code: "read_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    guard let done = pending else { return }
    pending = nil
    done(nil)
  }

  /// UTF-8 first, then the two encodings an Arabic sheet actually arrives
  /// in when the office saved it out of an older Excel. windows-1256 has no
  /// name in `String.Encoding`, so it comes the long way round through
  /// CoreFoundation.
  private static func decode(_ data: Data) -> String? {
    if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
    if let utf16 = String(data: data, encoding: .utf16) { return utf16 }
    let arabic = String.Encoding(
      rawValue: CFStringConvertEncodingToNSStringEncoding(
        CFStringEncoding(CFStringEncodings.windowsArabic.rawValue)
      )
    )
    return String(data: data, encoding: arabic)
  }
}
