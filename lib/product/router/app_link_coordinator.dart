import 'package:koala/product/router/app_link_destination.dart';

/// Native bağlantıyı oturum yüklemesiyle sıralayan küçük koordinatör.
///
/// Cold-start bağlantısı, router henüz oturumu okumamışken gelirse doğrudan
/// gezinmek muhafız tarafından splash'a geri çevrilir. Bu sınıf son geçerli
/// bağlantıyı bellekte tutar ve oturum hazır olduğunda yalnız bir kez açar.
class AppLinkCoordinator {
  AppLinkCoordinator({required this.appScheme});

  final String appScheme;

  String? _pendingRoute;

  /// Bağlantıyı doğrular; oturum hazırsa açar, değilse son geçerli rotayı
  /// bekletir. Geçersiz bir bağlantı mevcut bekleyen rotayı silemez.
  void handle(
    Uri uri, {
    required bool sessionInitialized,
    required void Function(String route) navigate,
  }) {
    final route = AppLinkDestination.routeFor(uri, appScheme: appScheme);
    if (route == null) return;

    if (!sessionInitialized) {
      _pendingRoute = route;
      return;
    }

    navigate(route);
  }

  /// Oturum okunduysa bekleyen rotayı alır, siler ve açar.
  void flush({
    required bool sessionInitialized,
    required void Function(String route) navigate,
  }) {
    if (!sessionInitialized) return;

    final route = _pendingRoute;
    if (route == null) return;
    _pendingRoute = null;
    navigate(route);
  }
}
