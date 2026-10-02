import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/employee/features/profile/presentation/pages/public_profile_page.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/features/dispute/dispute_routes.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/router/employee_routes.dart';
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

  test('şirket adresi shell dışında, kendi rotasıyla açılıyor', () {
    final address = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/business/company-address');

    // Harita ekranı navbar'ın üstünü kaplamalı (is-koala/koala#184).
    expect(address, hasLength(1));
    expect(address.single.pageBuilder, isNotNull);
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

  test('ulaşım planı düzenleyicisi ve alt sayfaları shell dışında', () {
    // Üçü de `/pick-address` gibi navbar'ın üstünü kaplar ve `pop` ile
    // taslağı geri verir (is-koala/koala#197).
    for (final path in [
      '/business/transport-plan',
      '/business/transport-shuttle',
      '/business/transport-stop',
    ]) {
      final route = allGoRoutes(
        RouterManager.router.configuration.routes,
      ).where((route) => route.path == path);

      expect(route, hasLength(1), reason: path);
      expect(route.single.pageBuilder, isNotNull, reason: path);
    }
  });

  test('yetenek havuzu shell dışında, kendi rotasıyla açılıyor', () {
    final pool = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/business/talent-pool');

    expect(pool, hasLength(1));
    expect(pool.single.pageBuilder, isNotNull);
  });

  test('uyuşmazlık ekranı shell dışında, atama kimliği yol parametresi', () {
    final routes = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == DisputeRoutes.pattern);

    // Navbar'ın üstünü kaplıyor ve iki kabuk da açıyor (is-koala/koala#215).
    expect(DisputeRoutes.pattern, '/assignment-dispute/:assignmentId');
    expect(DisputeRoutes.location('abc-1'), '/assignment-dispute/abc-1');
    expect(
      DisputeRoutes.location('a/b c'),
      '/assignment-dispute/a%2Fb%20c',
      reason: 'kimlik yola kaçışlanarak giriyor',
    );
    expect(routes, hasLength(1));
    expect(routes.single.pageBuilder, isNotNull);
    expect(routes.single.builder, isNull);
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

  test('iş detayı shell dışında, kendi rotasıyla açılıyor', () {
    final detail = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == '/work-detail');

    // İşlerim satırı ve Kazançlar satırı navbar'ın üstünü kaplayan tam
    // sayfaya açılıyor (is-koala/koala#177).
    expect(detail, hasLength(1));
    expect(detail.single.pageBuilder, isNotNull);
  });

  test('başkasının profili tek rota, shell dışında; işveren sayfası ayrı', () {
    final topLevel = RouterManager.router.configuration.routes
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toList();
    final all = allGoRoutes(RouterManager.router.configuration.routes).toList();

    // Çalışanın başkasının profilini açtığı rota navbar'ın üstünü kaplıyor
    // (is-koala/koala#182): shell'in içine değil üst düzeye konuyor. Kimlik
    // yol parametresi.
    expect(EmployeeRoutes.publicProfilePattern, '/public-profile/:userId');
    expect(EmployeeRoutes.publicProfile('user-9'), '/public-profile/user-9');
    expect(
      topLevel.where((path) => path == EmployeeRoutes.publicProfilePattern),
      hasLength(1),
    );
    final route = all.singleWhere(
      (route) => route.path == EmployeeRoutes.publicProfilePattern,
    );
    expect(route.pageBuilder, isNotNull);

    // İşverenin `/business/user-profile` sayfası ayrı kalıyor: iki kabuk iki
    // ayrı sayfa açıyor, biri ötekinin yerine geçmiyor.
    expect(
      all.where((route) => route.path == BusinessRoutes.userProfile),
      hasLength(1),
    );
  });

  // Kendi profiline yönlendirenler (`go`) ve bekçi `EmployeeRoutes.ownProfile`
  // sabitini okuyor; shell rotası da aynı sabitte durmalı, yoksa biri
  // değiştiğinde yönlendirme sessizce hiçbir yere gitmez.
  test('kendi profil sekmesi, sabitle aynı yolda tek shell rotası', () {
    final own = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).where((route) => route.path == EmployeeRoutes.ownProfile);

    expect(EmployeeRoutes.ownProfile, '/profile');
    expect(own, hasLength(1));
    expect(own.single.pageBuilder, isNotNull);
  });

  // Yol parametresi doğru kaynak: gerçek rotanın sayfa kurucusu eksik ya da
  // yanlış `extra` ile fırlatmamalı ve kimliği yoldan almalı.
  testWidgets('herkese açık profil rotası: extra eksik ya da yanlışsa açılır', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (built) {
          context = built;
          return const SizedBox.shrink();
        },
      ),
    );

    final route = allGoRoutes(
      RouterManager.router.configuration.routes,
    ).singleWhere((route) => route.path == EmployeeRoutes.publicProfilePattern);

    PublicProfilePage pageFor(Object? extra) {
      final state = GoRouterState(
        RouterManager.router.configuration,
        uri: Uri.parse(EmployeeRoutes.publicProfile('user-9')),
        matchedLocation: EmployeeRoutes.publicProfile('user-9'),
        fullPath: EmployeeRoutes.publicProfilePattern,
        pathParameters: const {'userId': 'user-9'},
        pageKey: const ValueKey('public-profile'),
        extra: extra,
      );
      final page = route.pageBuilder!(context, state) as MaterialPage<void>;
      return page.child as PublicProfilePage;
    }

    for (final extra in <Object?>[
      null,
      42,
      'user-9',
      const PublicProfileArgs(userId: 'user-1', name: 'Başkası'),
    ]) {
      final page = pageFor(extra);
      expect(page.args.userId, 'user-9', reason: '$extra');
      expect(page.args.name, isNull, reason: '$extra');
    }

    const matching = PublicProfileArgs(userId: 'user-9', name: 'Ayşe Yılmaz');
    expect(pageFor(matching).args, same(matching));
  });

  test('hesap modülünün rotaları tek, /business/ kopyaları yok', () {
    final routes = allGoRoutes(RouterManager.router.configuration.routes);
    final paths = routes.map((route) => route.path).toList();

    // Hesap kullanıcıya ait, tarafına değil: iki kabuk aynı rotaya gidiyor.
    for (final path in [
      AccountRoutes.accountInfo,
      AccountRoutes.address,
      AccountRoutes.changePassword,
      AccountRoutes.sessions,
      AccountRoutes.sessionDetail,
      AccountRoutes.notificationPreferences,
      AccountRoutes.reports,
      AccountRoutes.blockedUsers,
      AccountRoutes.accountDeletion,
      AccountRoutes.verification,
    ]) {
      expect(paths.where((p) => p == path), hasLength(1), reason: path);
      expect(path.startsWith('/business/'), isFalse, reason: path);
    }

    // Eski işveren kopyaları: `/business/sessions`, `/business/reports`,
    // `/business/blocked-users`, `/business/account-deletion`.
    for (final legacy in [
      '/business/sessions',
      '/business/reports',
      '/business/blocked-users',
      '/business/account-deletion',
    ]) {
      expect(paths, isNot(contains(legacy)), reason: '$legacy hâlâ var');
    }
  });
}
