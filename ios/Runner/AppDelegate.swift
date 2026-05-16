import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // -----------------------------------------------------------------
    // Google Maps iOS SDK initialization
    //
    // The Google Maps iOS SDK requires the API key to be provided
    // BEFORE the Flutter engine starts. To keep keys out of source
    // control we read it at runtime from `Laffeh-Secrets.plist` (which
    // is gitignored) OR from the GOOGLE_MAPS_API_KEY env variable
    // baked into the Xcode build configuration via a build phase.
    //
    // Easiest path for development:
    //   1. Run `flutter pub get`.
    //   2. Open `ios/Runner.xcworkspace` in Xcode.
    //   3. Add a `Laffeh-Secrets.plist` file with a single string key:
    //        GOOGLE_MAPS_API_KEY = <your key>
    //   4. Make sure GoogleMaps pod is installed (it is, via
    //      google_maps_flutter).
    //
    // Then uncomment the lines below and `import GoogleMaps`.
    // -----------------------------------------------------------------
    //
    // import GoogleMaps
    //
    // if let path = Bundle.main.path(forResource: "Laffeh-Secrets", ofType: "plist"),
    //    let secrets = NSDictionary(contentsOfFile: path),
    //    let key = secrets["GOOGLE_MAPS_API_KEY"] as? String {
    //   GMSServices.provideAPIKey(key)
    // }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
