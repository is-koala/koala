import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamanın tema tercihi: sistem, açık ya da koyu.
///
/// Tercih [ThemeMode] olarak tutuluyor; açık/koyu temayı Flutter'ın kendisi
/// [MaterialApp.themeMode] üzerinden seçiyor, böylece "sistem" seçeneği cihaz
/// ayarını canlı takip edebiliyor — kullanıcı telefonunu gece moduna alınca
/// uygulama yeniden açılmadan geçiyor.
class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'themeMode';

  /// Tercih tek bir bool olarak saklanırdı; eski kullanıcıların seçimi
  /// kaybolmasın diye ilk açılışta okunup yeni anahtara taşınıyor.
  static const String _legacyPrefsKey = 'isDarkMode';

  /// Varsayılan: cihazın ayarını takip et.
  static const ThemeMode _defaultMode = ThemeMode.system;

  ThemeMode _themeMode = _defaultMode;

  ThemeProvider() {
    _load();
  }

  /// Tercih diskten okunana kadar [_defaultMode] döner. Varsayılan "sistem"
  /// olduğu için çoğu kullanıcıda kayıtlı tercih yok ve açılışta geçiş de
  /// olmuyor; yalnızca cihaz ayarının tersini seçmiş kullanıcı ilk karede
  /// kısa bir geçiş görür.
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);

    if (stored != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == stored,
        orElse: () => _defaultMode,
      );
    } else if (prefs.containsKey(_legacyPrefsKey)) {
      // Eski sürümden gelen bool tercihi taşı.
      _themeMode = (prefs.getBool(_legacyPrefsKey) ?? false)
          ? ThemeMode.dark
          : ThemeMode.light;
      await prefs.setString(_prefsKey, _themeMode.name);
      await prefs.remove(_legacyPrefsKey);
    }

    notifyListeners();
  }
}
