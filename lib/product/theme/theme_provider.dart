import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema tercihi (sistem, açık, koyu). "Sistem" cihaz ayarını canlı izliyor.
class ThemeProvider with ChangeNotifier {
  static const String _prefsKey = 'themeMode';

  /// Eski bool tercih; ilk açılışta yeni anahtara taşınıyor.
  static const String _legacyPrefsKey = 'isDarkMode';

  static const ThemeMode _defaultMode = ThemeMode.system;

  ThemeMode _themeMode = _defaultMode;

  ThemeProvider() {
    _load();
  }

  /// Diskten okunana kadar [_defaultMode]; yalnız cihazın tersini seçen
  /// kullanıcı ilk karede kısa bir geçiş görür.
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
      _themeMode = (prefs.getBool(_legacyPrefsKey) ?? false)
          ? ThemeMode.dark
          : ThemeMode.light;
      await prefs.setString(_prefsKey, _themeMode.name);
      await prefs.remove(_legacyPrefsKey);
    }

    notifyListeners();
  }
}
