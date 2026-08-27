import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider yapıcısında `_load()` çağırıyor ve bu async; okuma bitene kadar
/// varsayılan dönüyor. Testlerde beklemek için bu yardımcı kullanılıyor.
Future<ThemeProvider> loadedProvider() async {
  final provider = ThemeProvider();
  await Future<void>.delayed(Duration.zero);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kayıt yoksa sistem temasında kalır', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = await loadedProvider();

    expect(provider.themeMode, ThemeMode.system);
  });

  test('kayıtlı tercih okunur', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});

    final provider = await loadedProvider();

    expect(provider.themeMode, ThemeMode.dark);
  });

  test('bozuk kayıt varsayılana düşer', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'neonPembe'});

    final provider = await loadedProvider();

    expect(provider.themeMode, ThemeMode.system);
  });

  test('setThemeMode diske yazar', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = await loadedProvider();

    await provider.setThemeMode(ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'light');
    expect(provider.themeMode, ThemeMode.light);
  });

  test('aynı moda set edilince bildirim atmaz', () async {
    SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
    final provider = await loadedProvider();

    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.setThemeMode(ThemeMode.dark);
    expect(notifications, 0);

    await provider.setThemeMode(ThemeMode.light);
    expect(notifications, 1);
  });

  group('eski isDarkMode tercihinin taşınması', () {
    test('true → koyu tema', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});

      final provider = await loadedProvider();

      expect(provider.themeMode, ThemeMode.dark);
    });

    test('false → açık tema', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': false});

      final provider = await loadedProvider();

      expect(provider.themeMode, ThemeMode.light);
    });

    test('taşıma sonrası yeni anahtar yazılır, eskisi silinir', () async {
      SharedPreferences.setMockInitialValues({'isDarkMode': true});

      await loadedProvider();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), 'dark');
      expect(prefs.containsKey('isDarkMode'), isFalse);
    });

    // Yeni anahtar varsa eskisi dikkate alınmamalı: kullanıcı taşımadan
    // sonra tercihini değiştirmiş olabilir.
    test('yeni anahtar varsa eski yok sayılır', () async {
      SharedPreferences.setMockInitialValues({
        'themeMode': 'light',
        'isDarkMode': true,
      });

      final provider = await loadedProvider();

      expect(provider.themeMode, ThemeMode.light);
    });
  });
}
