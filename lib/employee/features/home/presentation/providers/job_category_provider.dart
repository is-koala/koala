import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// Kategoriler bir kez çekilip elde tutulur; ilan formu ve keşfet aynı örneği
/// okur.
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

  /// Hata da olsa `true`: tekrar denemek çağıranın kararı, döngüye girilmesin.
  bool get hasLoaded => _hasLoaded;

  /// Kategori tanımlı değilse boş; hata değil ama seçici yerine açıklama
  /// gerekir.
  bool get isEmpty =>
      _hasLoaded && _categories.isEmpty && _errorMessage == null;

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

  JobCategory? byCode(String code) {
    for (final category in _categories) {
      if (category.code == code) return category;
    }
    return null;
  }
}
