import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Harita sekmesinin ilan durumu: görünen alan, arama ve pinler.
///
/// Harita listeden ayrı bir durum tutuyor — ikisini tek sağlayıcıya bağlamak
/// doğru yön ama ayrı bir iş. Ortak olan **sorgu modeli**: kamera kutusu
/// [JobSearchQuery]'nin sınırlayıcı kutu alanlarına yazılıyor, liste sekmesinin
/// kullandığı alanların aynısı.
///
/// Kamera her durduğunda istek atmıyor; üç koruma var:
/// 1. **Debounce** — hızlı kaydırmada tek istek çıkıyor.
/// 2. **Kapsama** — yeni alan bir öncekinin içindeyse ve önceki sonuç
///    kırpılmamışsa istek atılmıyor.
/// 3. **Jeton** — geç dönen eski yanıt yeni pinlerin üzerine yazamıyor.
class MapExploreController extends ChangeNotifier {
  MapExploreController({
    JobService? service,
    Duration debounce = const Duration(milliseconds: 500),
  }) : _service = service ?? JobService(),
       _debounce = debounce;

  /// Harita için istenen sayfa boyutu.
  ///
  /// Sunucunun tavanı 100 (`PageableSanitizer`); pin sayfalanamadığı için
  /// tavana kadar çıkılıyor. Yanıt `last: false` gelirse alanda daha fazla ilan
  /// var demektir — pinler sessizce düşürülmüyor, [isTruncated] açılıyor.
  static const int mapPageSize = 100;

  final JobService _service;
  final Duration _debounce;

  Timer? _timer;

  /// En son kamera olayının kutusu.
  JobMapBounds? _pendingBounds;

  /// En son **başarıyla** yüklenen kutu ve o yüklemenin kırpılmamış olup
  /// olmadığı. Kapsama kararı bu ikisine bakıyor.
  JobMapBounds? _loadedBounds;
  bool _loadedComplete = false;

  /// Uçan isteğin sıra numarası; yanıt döndüğünde hâlâ güncel mi diye
  /// karşılaştırılıyor.
  int _requestToken = 0;

  List<Job> _jobs = const [];
  String _searchText = '';
  bool _isLoading = false;
  bool _isTruncated = false;
  bool _disposed = false;
  String? _errorMessage;

  List<Job> get jobs => List.unmodifiable(_jobs);

  String get searchText => _searchText;

  bool get isLoading => _isLoading;

  /// Görünen alanda [mapPageSize] taneden fazla ilan var mı. Arayüz bunu
  /// "yaklaş" uyarısı olarak gösteriyor.
  bool get isTruncated => _isTruncated;

  String? get errorMessage => _errorMessage;

  /// Kamera durduğunda çağrılıyor.
  void onCameraIdle(JobMapBounds bounds) {
    _pendingBounds = bounds;

    // Önceki sonuç bu alanı zaten kapsıyorsa ve kırpılmamışsa yeni istek
    // hiçbir şey eklemez. Kırpılmış bir sonuçta ise yaklaşmak **yeni** pin
    // getirebilir, o yüzden orada istek atılıyor.
    final loaded = _loadedBounds;
    if (_loadedComplete && loaded != null && loaded.contains(bounds)) return;

    _schedule();
  }

  /// Harita arama kutusu. Metin mevcut kutuyla birlikte sunucuya gidiyor;
  /// eskiden eldeki ≤20 satır bellekte süzülüyordu.
  void setSearchText(String text) {
    if (text == _searchText) return;

    _searchText = text;
    // Arama değişti: kapsama koruması artık geçerli değil, aynı kutu için de
    // yeniden sorulmalı.
    _loadedBounds = null;
    _loadedComplete = false;
    _schedule();
  }

  /// Hata sonrası kullanıcının "Tekrar Dene"si.
  void retry() {
    _loadedBounds = null;
    _loadedComplete = false;
    _schedule();
  }

  void _schedule() {
    if (_disposed || _pendingBounds == null) return;

    _timer?.cancel();
    _timer = Timer(_debounce, _fetch);
  }

  Future<void> _fetch() async {
    final bounds = _pendingBounds;
    if (_disposed || bounds == null) return;

    final token = ++_requestToken;

    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final page = await _service.search(
        JobSearchQuery(query: _searchText, bounds: bounds),
        size: mapPageSize,
      );

      // Geç dönen eski yanıt: aradan yeni bir istek geçmişse bu yanıt bayat.
      if (token != _requestToken) return;

      _jobs = page.jobs;
      _isTruncated = !page.last;
      _loadedBounds = bounds;
      _loadedComplete = page.last;
    } on ApiException catch (error) {
      if (token != _requestToken) return;

      // Eldeki pinler silinmiyor: hata yüzünden haritayı boşaltmak
      // kullanıcının baktığı bilgiyi de götürürdü.
      _errorMessage = error.message;
    } finally {
      if (token == _requestToken) {
        _isLoading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
