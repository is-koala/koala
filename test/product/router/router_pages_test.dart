import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/router/router_manager.dart';

/// Bir rotanın sayfasını go_router'a seçtirmek (`builder:`) bu sürümde
/// sessizce `NoTransitionPage` üretiyordu: shell dışındaki bütün sayfalar
/// animasyonsuz açılıyordu ve hiçbir yerde hata görünmüyordu. Her rota
/// sayfasını açıkça vermek zorunda.
void main() {
  Iterable<GoRoute> allGoRoutes(List<RouteBase> routes) sync* {
    for (final route in routes) {
      if (route is GoRoute) yield route;
      yield* allGoRoutes(route.routes);
    }
  }

  test('her rota kendi sayfasını veriyor', () {
    final routes = allGoRoutes(RouterManager.router.configuration.routes);

    expect(routes, isNotEmpty);
    for (final route in routes) {
      expect(
        route.pageBuilder,
        isNotNull,
        reason: '${route.path} sayfasını go_router seçiyor',
      );
      expect(
        route.builder,
        isNull,
        reason: '${route.path} hem builder hem pageBuilder taşıyor',
      );
    }
  });

  test('şirket galerisi shell dışında, kendi rotasıyla açılıyor', () {
    final gallery = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/business/company-gallery');

    // Galeri navbar'ın üstünü kaplamalı, o yüzden shell'in içine değil üst
    // düzeye konuyor — `/business/company-info` ile aynı yerde.
    expect(gallery, hasLength(1));
    expect(gallery.single.pageBuilder, isNotNull);
  });
}
