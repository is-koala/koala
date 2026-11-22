import 'package:koala/product/router/app_link_destination.dart';

/// Uygulama bağlantısını oturum yüklemesiyle sıralar: soğuk açılışta router
/// oturumu okumadan gelen bağlantı muhafıza takılırdı. Son geçerli bağlantı
/// bekletilir ve oturum hazır olunca bir kez açılır.
class AppLinkCoordinator {
  AppLinkCoordinator({required this.appScheme, required this.webHosts});

  final String appScheme;

  final Set<String> webHosts;

  String? _pendingRoute;

  /// Geçersiz bağlantı bekleyen rotayı silemez.
  void handle(
    Uri uri, {
    required bool sessionInitialized,
    required void Function(String route) navigate,
  }) {
    final route = AppLinkDestination.routeFor(
      uri,
      appScheme: appScheme,
      webHosts: webHosts,
    );
    if (route == null) return;

    if (!sessionInitialized) {
      _pendingRoute = route;
      return;
    }

    navigate(route);
  }

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
