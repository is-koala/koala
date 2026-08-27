import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps SDK'sı motordan bağımsız, uygulama düzeyinde bir servis; ilk harita
    // görünümü oluşmadan önce anahtarı almış olması yeterli.
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String
    GMSServices.provideAPIKey(mapsApiKey ?? "")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene yaşam döngüsünde eklentiler artık burada kaydediliyor: örtük motor
  // hazır olduğunda çağrılıyor, didFinishLaunchingWithOptions'ta değil.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
