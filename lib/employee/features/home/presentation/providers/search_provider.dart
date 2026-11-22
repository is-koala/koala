import 'package:material_ui/material_ui.dart';

/// Haritanın arama kipi: çubuk açık mı. Metin burada tutulmuyor; `TextField` ve
/// `MapExploreController` tutuyor, üçüncü kopya ayrışırdı.
class SearchProvider extends ChangeNotifier {
  bool _isSearching = false;

  bool get isSearching => _isSearching;

  void startSearching() {
    _isSearching = true;
    notifyListeners();
  }

  void stopSearching() {
    _isSearching = false;
    notifyListeners();
  }
}
