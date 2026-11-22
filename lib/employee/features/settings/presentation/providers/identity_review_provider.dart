import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Son kimlik incelemesi, uygulama boyunca. `/users/me` bunu taşımadığı için
/// ayrı uçtan; açılışta çekilir, gönderimde yanıtla güncellenir.
class IdentityReviewProvider extends ChangeNotifier {
  IdentityReviewProvider({IdentityDocumentService? service})
    : _service = service ?? IdentityDocumentService();

  final IdentityDocumentService _service;

  IdentityReview? _review;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// İkinci [load] bunu bekler: karar bitmemiş okumanın eski değerine değil
  /// yanıtın kendisine dayanmalı.
  Future<void>? _inFlight;

  /// Çıkıştan sonra dönen istekler yeni oturuma yazmasın.
  int _generation = 0;

  /// Yükleme yoksa ya da okunmadıysa `null`; [hasLoaded] ayırır.
  IdentityReview? get review => _review;

  bool get isLoading => _isLoading;

  /// `false` iken `null` "bilinmiyor" demek.
  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  IdentityStatus statusFor({required bool identityVerified}) {
    return IdentityStatus.resolve(
      identityVerified: identityVerified,
      review: _review,
    );
  }

  /// [silent] göstergeyi açmaz. Hatada eldeki kayıt korunur: bayat durum hiç
  /// durumdan iyi.
  Future<void> load({bool silent = false}) {
    final pending = _inFlight;
    if (pending != null) return pending;

    final request = _load(silent: silent);
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<void> _load({required bool silent}) async {
    final generation = _generation;

    _isLoading = !silent;
    _errorMessage = null;
    notifyListeners();

    try {
      final review = await _service.fetchCurrent();
      if (generation != _generation) return;
      _review = review;
      _hasLoaded = true;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = error.message;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// `POST` açılan incelemeyi döndürüyor; ikinci okuma yok.
  void apply(IdentityReview review) {
    _review = review;
    _hasLoaded = true;
    _errorMessage = null;
    notifyListeners();
  }

  void clear() {
    _generation++;
    _review = null;
    _hasLoaded = false;
    _inFlight = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
