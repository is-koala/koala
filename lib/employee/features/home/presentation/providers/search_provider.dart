import 'package:flutter/material.dart';

/// Haritanın arama kipi: arama çubuğu açık mı, değil mi.
///
/// Aranan metnin kendisi burada **durmuyor**. Bir zamanlar duruyordu (`query`,
/// `setQuery`, `clearQuery`) ama hiçbir yerde okunmuyordu: metni `TextField`'ın
/// kendi denetleyicisi tutuyor, sunucuya gideni `MapExploreController` tutuyor.
/// Üçüncü bir kopya yalnızca senkron kalması gereken bir yer daha demekti —
/// ve okunmadığı için senkronsuzluğu kimse fark etmezdi.
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
