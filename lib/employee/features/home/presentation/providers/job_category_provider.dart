import 'package:flutter/material.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kategori listesini bir kez çekip uygulama boyunca elde tutar.
///
/// Liste nadiren değiştiği için her ekranda yeniden istenmiyor; ilan oluşturma
/// seçicisi ve keşfet filtresi aynı örneği okuyor.
class JobCategoryProvider extends ChangeNotifier {
  JobCategoryProvider({JobCategoryService? service})
    : _service = service ?? JobCategoryService();

  final JobCategoryService _service;

  List<JobCategory> _categories = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<JobCategory> get categories => List.unmodifiable(_categories);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// Liste bir kez çekildi mi. Hata da olsa `true`: sonsuz döngüye girmemek
  /// için tekrar denemek çağıranın açık kararı olmalı.
  bool get hasLoaded => _hasLoaded;

  /// Backend'de henüz kategori tanımlı değilse boş liste dönüyor; bu bir hata
  /// değil ama arayüzün seçici yerine açıklama göstermesi gereken durum.
  bool get isEmpty =>
      _hasLoaded && _categories.isEmpty && _errorMessage == null;

  /// Kategorileri çeker. Daha önce başarıyla çekildiyse ağa çıkmaz;
  /// [force] ile yeniden denenebilir.
  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _service.fetchCategories();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Koda karşılık gelen kategori; yoksa `null`.
  JobCategory? byCode(String code) {
    for (final category in _categories) {
      if (category.code == code) return category;
    }
    return null;
  }
}
