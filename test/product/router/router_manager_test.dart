import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/features/dispute/dispute_routes.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/router/router_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yönlendirme muhafızı uygulamanın en kritik mantığı: employee ve business
/// arayüzlerini birbirinden ayıran tek yer burası. Sızdırırsa kullanıcı
/// karşı tarafın ekranını görür.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String? redirect({
    required bool loggedIn,
    String? userType,
    required String location,
    bool initialized = true,
    bool seenOnboarding = true,
  }) => RouterManager.resolveRedirect(
    loggedIn: loggedIn,
    userType: userType,
    location: location,
    initialized: initialized,
    seenOnboarding: seenOnboarding,
  );

  group('giriş yapmamış kullanıcı', () {
    test('korumalı bir sayfaya girerse giriş ekranına atılır', () {
      for (final location in [
        '/explore',
        '/jobs',
        '/chat',
        '/profile',
        '/business/home',
        '/settings',
        '/apply',
      ]) {
        expect(
          redirect(loggedIn: false, location: location),
          '/auth',
          reason: '$location korumasız kalmış',
        );
      }
    });

    test('auth sayfalarında serbest bırakılır', () {
      for (final location in [
        '/auth',
        '/onboarding',
        '/auth/register-type/register',
      ]) {
        expect(redirect(loggedIn: false, location: location), isNull);
      }
    });

    test('yalnız tam token karşılama rotaları public kabul edilir', () {
      for (final location in ['/reset-password', '/email-verification']) {
        expect(redirect(loggedIn: false, location: location), isNull);
        expect(
          redirect(loggedIn: false, location: '$location-attacker'),
          '/auth',
        );
      }
    });
  });

  group('giriş yapmış employee', () {
    test('kendi sayfalarında serbest bırakılır', () {
      for (final location in [
        '/explore',
        '/jobs',
        '/chat',
        '/profile',
        '/availability',
        '/earnings',
        EmployeeRoutes.publicProfile('user-9'),
      ]) {
        expect(
          redirect(loggedIn: true, userType: 'employee', location: location),
          isNull,
          reason: '$location çalışanın önünü kesiyor',
        );
      }
    });

    test('business sayfalarına giremez', () {
      for (final location in [
        '/business',
        '/business/home',
        '/business/posts',
        '/business/create',
        '/business/job-detail',
        '/business/applications',
      ]) {
        expect(
          redirect(loggedIn: true, userType: 'employee', location: location),
          '/explore',
          reason: '$location business tarafına sızdırıyor',
        );
      }
    });

    // Kendi profil sekmesinin yolu tek sabitte: bekçi, shell rotası ve
    // "kendi profiline yönlendir" aynı dizgeyi okuyor.
    test('kendi profil sekmesi serbest, işverene kapalı', () {
      expect(
        redirect(
          loggedIn: true,
          userType: 'employee',
          location: EmployeeRoutes.ownProfile,
        ),
        isNull,
      );
      expect(
        redirect(
          loggedIn: true,
          userType: 'business',
          location: EmployeeRoutes.ownProfile,
        ),
        '/business/home',
      );
    });

    test('auth sayfasına dönerse explore\'a alınır', () {
      expect(
        redirect(loggedIn: true, userType: 'employee', location: '/'),
        '/explore',
      );
    });
  });

  group('giriş yapmış business', () {
    test('kendi sayfalarında serbest bırakılır', () {
      for (final location in [
        '/business/home',
        '/business/posts',
        '/business/chat',
        '/business/profile',
        '/business/applications',
      ]) {
        expect(
          redirect(loggedIn: true, userType: 'business', location: location),
          isNull,
        );
      }
    });

    test('employee sayfalarına giremez', () {
      for (final location in [
        '/explore',
        '/jobs',
        '/chat',
        '/profile',
        '/availability',
        '/earnings',
        EmployeeRoutes.publicProfile('user-9'),
      ]) {
        expect(
          redirect(loggedIn: true, userType: 'business', location: location),
          '/business/home',
          reason: '$location employee tarafına sızdırıyor',
        );
      }
    });

    test('auth sayfasına dönerse business home\'a alınır', () {
      expect(
        redirect(loggedIn: true, userType: 'business', location: '/'),
        '/business/home',
      );
    });
  });

  group('user_type eksik ya da bozuk', () {
    test('null tip employee gibi davranır, auth\'tan explore\'a gider', () {
      expect(redirect(loggedIn: true, location: '/'), '/explore');
    });

    // Bilinmeyen bir tip iki taraftan da dışlanmıyor; guard yalnızca
    // 'business' ve 'employee' değerlerini tanıyor. Davranışın farkında
    // olalım diye kayıt altında.
    test('bilinmeyen tip business sayfalarında engellenmez', () {
      expect(
        redirect(loggedIn: true, userType: 'admin', location: '/business/home'),
        isNull,
      );
    });
  });

  group('startsWith kaynaklı kenar durumlar', () {
    // Guard prefix eşleşmesi yapıyor: '/business' ile başlayan her yol
    // business sayılıyor.
    test('employee için /businessX de business sayılır', () {
      expect(
        redirect(
          loggedIn: true,
          userType: 'employee',
          location: '/business-info',
        ),
        '/explore',
      );
    });

    test('tanınmayan bir yol giriş yapmış kullanıcıya açık', () {
      expect(
        redirect(loggedIn: true, userType: 'employee', location: '/settings'),
        isNull,
      );
    });

    // Hesap modülünün ekranları iki uygulamanın da ayarlarından açılıyor ve
    // her birinin tek rotası var. `/business` önekini taşımadıkları için
    // işverenin, employee rota listesinde olmadıkları için çalışanın önü
    // kesilmemeli.
    test('hesap modülü rotaları her iki tarafa da açık', () {
      for (final userType in ['employee', 'business']) {
        for (final location in [
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
          expect(
            redirect(loggedIn: true, userType: userType, location: location),
            isNull,
            reason: '$userType $location ekranına ulaşamıyor',
          );
        }
      }
    });
  });

  // Uyuşmazlık ekranını çalışan da işveren de açıyor (is-koala/koala#215): yol
  // ne `/business` öneki taşıyor ne çalışan listesine giriyor, yoksa bir taraf
  // geri çevrilirdi.
  group('uyuşmazlık ekranı', () {
    test('her iki tarafa da açık', () {
      for (final userType in ['employee', 'business']) {
        expect(
          redirect(
            loggedIn: true,
            userType: userType,
            location: DisputeRoutes.location('assignment-1'),
          ),
          isNull,
          reason: '$userType uyuşmazlık ekranına ulaşamıyor',
        );
      }
    });

    test('giriş yapmamış kullanıcı giriş ekranına atılır', () {
      expect(
        redirect(
          loggedIn: false,
          location: DisputeRoutes.location('assignment-1'),
        ),
        '/auth',
      );
    });
  });

  // Açılışta oturum durumu okunana kadar hiçbir karar verilemez: "okunmadı"
  // ile "giriş yapmamış" karıştırılırsa kullanıcı bir an giriş ekranını görüp
  // sonra ana sayfaya atlıyor.
  group('oturum durumu henüz okunmadıysa', () {
    test('nerede olursa olsun splash\'ta bekletilir', () {
      for (final location in ['/explore', '/business/home', '/auth']) {
        expect(
          redirect(loggedIn: false, location: location, initialized: false),
          '/',
        );
      }
    });

    test('splash\'ta serbest bırakılır', () {
      expect(
        redirect(loggedIn: false, location: '/', initialized: false),
        isNull,
      );
    });
  });

  // Splash geçici bir ekran. Onu auth rotalarıyla aynı kümeye koymak, giriş
  // yapmamış kullanıcıyı "zaten auth'ta" sayıp açılışta orada kilitliyordu.
  group('oturum okunduktan sonra splash', () {
    test('giriş yapmamış kullanıcı giriş ekranına çıkarılır', () {
      expect(redirect(loggedIn: false, location: '/'), '/auth');
    });

    test('tanıtımı görmemiş kullanıcı tanıtıma çıkarılır', () {
      expect(
        redirect(loggedIn: false, location: '/', seenOnboarding: false),
        '/onboarding',
      );
    });

    test('employee kendi ana sayfasına çıkarılır', () {
      expect(
        redirect(loggedIn: true, userType: 'employee', location: '/'),
        '/explore',
      );
    });

    test('business kendi ana sayfasına çıkarılır', () {
      expect(
        redirect(loggedIn: true, userType: 'business', location: '/'),
        '/business/home',
      );
    });

    test('hiçbir durumda splash\'ta kalınmaz', () {
      for (final loggedIn in [true, false]) {
        for (final seen in [true, false]) {
          expect(
            redirect(loggedIn: loggedIn, location: '/', seenOnboarding: seen),
            isNotNull,
            reason: 'loggedIn=$loggedIn seenOnboarding=$seen splash\'ta kaldı',
          );
        }
      }
    });
  });

  group('onboarding', () {
    test('görülmemişse giriş yerine tanıtıma atılır', () {
      expect(
        redirect(loggedIn: false, location: '/explore', seenOnboarding: false),
        '/onboarding',
      );
    });

    test('görülmüşse doğrudan giriş ekranına atılır', () {
      expect(redirect(loggedIn: false, location: '/explore'), '/auth');
    });
  });

  // Muhafız senkron okumak zorunda: `await` eden bir redirect her `push`'ı
  // kareden sonraya atıyor ve sayfa geçişleri oynamıyor.
  group('SessionManager oturum durumu', () {
    setUp(() {
      SessionManager().resetForTest();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() => SessionManager().resetForTest());

    test('load edilmeden okunmamış sayılır', () {
      expect(SessionManager().isInitialized, isFalse);
      expect(SessionManager().isLoggedIn, isFalse);
      expect(SessionManager().userType, isNull);
    });

    test('load sonrası bayraklar senkron okunuyor', () async {
      SharedPreferences.setMockInitialValues({
        SessionManager.seenOnboardingKey: true,
      });
      FlutterSecureStorage.setMockInitialValues({});
      await SessionManager().start(
        accessToken: 'access',
        refreshToken: 'refresh',
        isEmployer: true,
      );
      SessionManager().resetForTest();

      await SessionManager().load();

      expect(SessionManager().isInitialized, isTrue);
      expect(SessionManager().isLoggedIn, isTrue);
      expect(SessionManager().userType, SessionManager.businessType);
      expect(SessionManager().seenOnboarding, isTrue);
    });

    // Yazan yollar da örneği belleğe alıyor: load çağrılmamışken açılan bir
    // oturum "durum okunmadı" olarak kalsa muhafız kullanıcıyı splash'a
    // kilitlerdi.
    test('load çağrılmadan yazan bir yol da durumu okunmuş yapıyor', () async {
      expect(SessionManager().isInitialized, isFalse);

      await SessionManager().markOnboardingSeen();

      expect(SessionManager().isInitialized, isTrue);
      expect(SessionManager().seenOnboarding, isTrue);
    });

    test('load dinleyicileri uyandırıyor', () async {
      var bildirim = 0;
      void listener() => bildirim++;
      SessionManager().addListener(listener);

      await SessionManager().load();
      SessionManager().removeListener(listener);

      expect(bildirim, 1);
    });

    // Yazan akışlar da aynı `getInstance()` örneğinden geçtiği için bellekteki
    // değer bayatlamıyor: çıkış aynı karede görülüyor.
    test('oturum kapanınca bayrak aynı anda düşüyor', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await SessionManager().start(
        accessToken: 'access',
        refreshToken: 'refresh',
        isEmployer: false,
      );
      await SessionManager().load();
      expect(SessionManager().isLoggedIn, isTrue);

      await SessionManager().end();

      expect(SessionManager().isLoggedIn, isFalse);
    });
  });

  test('paylaşılan ilan çalışana açık, işveren ana sayfasına yönlenir', () {
    expect(
      RouterManager.resolveRedirect(
        initialized: true,
        loggedIn: true,
        userType: 'employee',
        seenOnboarding: true,
        location: '/shared-job?id=x',
      ),
      isNull,
    );
    expect(
      RouterManager.resolveRedirect(
        initialized: true,
        loggedIn: true,
        userType: 'business',
        seenOnboarding: true,
        location: '/shared-job?id=x',
      ),
      '/business/home',
    );
  });

  test(
    'biniş rotaları tarafına göre korunur, bağlantı sayfası ikisine açık',
    () {
      String? redirectFor(String userType, String location) =>
          RouterManager.resolveRedirect(
            initialized: true,
            loggedIn: true,
            userType: userType,
            seenOnboarding: true,
            location: location,
          );

      final workerQr = EmployeeRoutes.boardingQrLocation('asg-1', 'OUTBOUND');
      final workerScan = EmployeeRoutes.boardingScanLocation();
      expect(redirectFor('employee', workerQr), isNull);
      expect(redirectFor('employee', workerScan), isNull);
      expect(redirectFor('business', workerQr), '/business/home');
      expect(redirectFor('business', workerScan), '/business/home');

      expect(
        redirectFor('employee', '/business/shuttle-boardings?shuttleId=s'),
        '/explore',
      );
      expect(
        redirectFor('business', '/business/shuttle-boardings?shuttleId=s'),
        isNull,
      );

      for (final userType in ['employee', 'business']) {
        expect(
          redirectFor(userType, '${RouterManager.boardingLinkPath}?t=x'),
          isNull,
        );
      }
    },
  );
}
