import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Laffah is read off a windscreen mount mid-route, so the screen must
    // never sleep while the app is up. Set once: iOS keeps it for the life of
    // the process and stops honouring it the moment we are backgrounded, so
    // there is no battery cost off screen and nothing to undo. App-wide on
    // purpose — not just during drive mode.
    application.isIdleTimerDisabled = true

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
