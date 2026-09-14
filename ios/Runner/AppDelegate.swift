import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Dart tarafının "harita bu derlemede var mı" diye sorduğu kanal;
  /// `lib/product/services/maps_availability.dart` ile aynı ad.
  private static let mapsAvailabilityChannel = "com.iskoala.koala/maps_availability"

  /// `GMSServices.provideAPIKey` çağrıldı mı. Anahtar boşken çağrılmıyor ve
  /// ilk `GoogleMap` `GMSServicesException` ile uygulamayı çökertiyor
  /// (is-koala/koala#172); Dart bu bayrağa bakıp haritayı hiç kurmuyor.
  private var mapsApiKeyProvided = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Maps SDK'sı motordan bağımsız, uygulama düzeyinde bir servis; ilk harita
    // görünümü oluşmadan önce anahtarı almış olması yeterli.
    let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String
    if let mapsApiKey, !mapsApiKey.isEmpty {
      GMSServices.provideAPIKey(mapsApiKey)
      mapsApiKeyProvided = true
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // UIScene yaşam döngüsünde eklentiler artık burada kaydediliyor: örtük motor
  // hazır olduğunda çağrılıyor, didFinishLaunchingWithOptions'ta değil.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerMapsAvailabilityChannel(with: engineBridge.applicationRegistrar.messenger())
  }

  /// Uygulama düzeyi kanal: `isAvailable` → anahtar verildiyse `true`.
  private func registerMapsAvailabilityChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.mapsAvailabilityChannel,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "isAvailable":
        result(self?.mapsApiKeyProvided ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
