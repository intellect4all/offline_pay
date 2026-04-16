import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // H-01 Core NFC merchant reader. Available on iOS 13+; the plugin
    // itself guards with `NFCTagReaderSession.readingAvailable`.
    if #available(iOS 13.0, *) {
      if let registrar = self.registrar(forPlugin: "OfflinePayNfcReaderPlugin") {
        OfflinePayNfcReaderPlugin.register(with: registrar)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
