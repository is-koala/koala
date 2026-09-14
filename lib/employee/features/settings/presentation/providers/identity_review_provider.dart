import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Oturum sahibinin son kimlik incelemesi, uygulama boyunca.
///
/// Profil rozeti, hesap bilgileri satırı ve kimlik ekranları aynı kaydı
/// okuyor; `/users/me` bu bilgiyi taşımadığı için ([CurrentUser] yalnız
/// `identityVerified` biliyor) ayrı bir uçtan geliyor ve [UserProvider]
/// gibi burada tutuluyor. Açılışta bir kez çekiliyor, gönderim sonrası
/// yanıtla yerinde güncelleniyor.
class IdentityReviewProvider extends ChangeNotifier {
  IdentityReviewProvider({IdentityDocumentService? service})
    : _service = service ?? IdentityDocumentService();

  final IdentityDocumentService _service;

  IdentityReview? _review;
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// Ağda bekleyen okuma. İkinci bir [load] yeni istek açmak yerine bunu
  /// bekliyor: açılışta arka planda başlayan okuma sürerken kimlik ekranı
  /// açılırsa, ekranın kararı bitmemiş bir okumanın eski değerine değil
  /// yanıtın kendisine dayanmalı.
  Future<void>? _inFlight;

  /// Çıkıştan sonra tamamlanan isteklerin yeni oturuma yazmasını engeller.
  int _generation = 0;

  /// Son inceleme; hiç yükleme yoksa ya da henüz okunmadıysa `null`.
  /// İkisini [hasLoaded] ayırıyor.
  IdentityReview? get review => _review;

  bool get isLoading => _isLoading;

  /// Sunucuya en az bir kez sorulup yanıt alındı mı. `false` iken `null`
  /// [review] "bilinmiyor" demek, "yok" değil.
  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  /// Kullanıcının kimlik durumu; bayrak `/users/me`'den, inceleme buradan.
  IdentityStatus statusFor({required bool identityVerified}) {
    return IdentityStatus.resolve(
      identityVerified: identityVerified,
      review: _review,
    );
  }

  /// İncelemeyi sunucudan okur.
  ///
  /// [silent] açıkken yükleme göstergesi açılmıyor; rozet çizilirken ve
  /// açılışta arka planda tazelerken kullanılıyor. Hata durumunda eldeki
  /// kayıt korunuyor: bayat bir durum, hiç durum göstermemekten iyi.
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

  /// Gönderim yanıtını yerine koyar; ikinci bir okuma isteği atılmıyor,
  /// `POST` zaten açılan incelemeyi döndürüyor.
  void apply(IdentityReview review) {
    _review = review;
    _hasLoaded = true;
    _errorMessage = null;
    notifyListeners();
  }

  /// Çıkışta: bir sonraki oturum öncekinin inceleme durumunu görmesin.
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
