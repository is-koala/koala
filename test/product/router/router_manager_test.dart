import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/router/router_manager.dart';

/// Yönlendirme muhafızı uygulamanın en kritik mantığı: employee ve business
/// arayüzlerini birbirinden ayıran tek yer burası. Sızdırırsa kullanıcı
/// karşı tarafın ekranını görür.
void main() {
  String? redirect({
    required bool loggedIn,
    String? userType,
    required String location,
  }) => RouterManager.resolveRedirect(
    loggedIn: loggedIn,
    userType: userType,
    location: location,
  );

  group('giriş yapmamış kullanıcı', () {
    test('korumalı bir sayfaya girerse authgate\'e atılır', () {
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
          '/authgate',
          reason: '$location korumasız kalmış',
        );
      }
    });

    test('auth sayfalarında serbest bırakılır', () {
      for (final location in [
        '/auth',
        '/authgate',
        '/onboarding',
        '/auth/register-type/register',
      ]) {
        expect(redirect(loggedIn: false, location: location), isNull);
      }
    });
  });

  group('giriş yapmış employee', () {
    test('kendi sayfalarında serbest bırakılır', () {
      for (final location in ['/explore', '/jobs', '/chat', '/profile']) {
        expect(
          redirect(loggedIn: true, userType: 'employee', location: location),
          isNull,
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
      ]) {
        expect(
          redirect(loggedIn: true, userType: 'employee', location: location),
          '/explore',
          reason: '$location business tarafına sızdırıyor',
        );
      }
    });

    test('auth sayfasına dönerse explore\'a alınır', () {
      expect(
        redirect(loggedIn: true, userType: 'employee', location: '/authgate'),
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
      ]) {
        expect(
          redirect(loggedIn: true, userType: 'business', location: location),
          isNull,
        );
      }
    });

    test('employee sayfalarına giremez', () {
      for (final location in ['/explore', '/jobs', '/chat', '/profile']) {
        expect(
          redirect(loggedIn: true, userType: 'business', location: location),
          '/business/home',
          reason: '$location employee tarafına sızdırıyor',
        );
      }
    });

    test('auth sayfasına dönerse business home\'a alınır', () {
      expect(
        redirect(loggedIn: true, userType: 'business', location: '/authgate'),
        '/business/home',
      );
    });
  });

  group('user_type eksik ya da bozuk', () {
    test('null tip employee gibi davranır, auth\'tan explore\'a gider', () {
      expect(redirect(loggedIn: true, location: '/authgate'), '/explore');
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
  });
}
