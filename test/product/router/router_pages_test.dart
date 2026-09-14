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

  test('şirket yetkilileri shell dışında, kendi rotasıyla açılıyor', () {
    final contacts = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/business/company-contacts');

    expect(contacts, hasLength(1));
    expect(contacts.single.pageBuilder, isNotNull);
  });

  test('şirket daveti shell dışında, kendi rotasıyla açılıyor', () {
    final invitation = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/company-invitation');

    expect(invitation, hasLength(1));
    expect(invitation.single.pageBuilder, isNotNull);
  });

  test('yetenek havuzu shell dışında, kendi rotasıyla açılıyor', () {
    final pool = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/business/talent-pool');

    expect(pool, hasLength(1));
    expect(pool.single.pageBuilder, isNotNull);
  });

  test('adres seçici tek rotayla iki uygulamaya da açık', () {
    final routes = allGoRoutes(RouterManager.router.configuration.routes);

    // Harita-öncelikli adres ekranı: işveren ilan ve şirket adresini,
    // çalışan `/address` üzerinden kendi adresini aynı bileşenle seçiyor.
    // `/business/` öneki taşımıyor ki yönlendirme kapısı çalışanı geri
    // çevirmesin; eski `pick-location` rotaları kalktı.
    final picker = routes.where((route) => route.path == '/pick-address');
    expect(picker, hasLength(1));
    expect(picker.single.pageBuilder, isNotNull);
    expect(
      routes.where((route) => route.path.endsWith('pick-location')),
      isEmpty,
    );
  });

  test(
    'fotoğraflı kimlik incelemesi shell dışında, kendi rotasıyla açılıyor',
    () {
      final documents = allGoRoutes(
        RouterManager.router.configuration.routes,
      ).where((route) => route.path == '/identity-documents');

      // Çip ekranı gibi kimlik ekranının üstüne tam sayfa açılıyor.
      expect(documents, hasLength(1));
      expect(documents.single.pageBuilder, isNotNull);
    },
  );

  test('kazançlar ekranı shell dışında, kendi rotasıyla açılıyor', () {
    final earnings = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/earnings');

    expect(earnings, hasLength(1));
    expect(earnings.single.pageBuilder, isNotNull);
  });
}
