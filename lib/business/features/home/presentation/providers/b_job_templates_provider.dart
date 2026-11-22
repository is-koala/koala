import 'package:material_ui/material_ui.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/business/features/home/services/job_template_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İlan şablonları; sayfasız, bir kez çekilir. Silme iyimser: reddedilirse
/// satır geri konur.
class BJobTemplatesProvider extends ChangeNotifier {
  BJobTemplatesProvider({JobTemplateService? service})
    : _service = service ?? JobTemplateService();

  final JobTemplateService _service;

  final List<JobTemplate> _templates = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// Çıkıştan sonra dönen istekler yeni listeye yazmasın.
  int _generation = 0;

  List<JobTemplate> get templates => List.unmodifiable(_templates);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final templates = await _service.fetchTemplates();
      if (generation != _generation) return;
      _templates
        ..clear()
        ..addAll(templates);
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = _messageFor(error);
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  /// Başarıda şablon başa girer (sunucu da en yeniyi başta döndürüyor).
  Future<bool> createFromJob({
    required String jobId,
    required String templateName,
  }) async {
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    final generation = _generation;
    try {
      final created = await _service.createFromJob(
        jobId: jobId,
        templateName: templateName,
      );
      if (generation != _generation) return false;
      _templates.insert(0, created);
      return true;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = _messageFor(error);
      return false;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> delete(String templateId) async {
    final index = _templates.indexWhere(
      (template) => template.id == templateId,
    );
    if (index < 0) return false;

    final removed = _templates.removeAt(index);
    final generation = _generation;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.deleteTemplate(templateId);
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _templates.insert(index, removed);
        _errorMessage = _messageFor(error);
        notifyListeners();
      }
      return false;
    }
  }

  /// Kod `errorCode`'dan: iki durum da `404` ve düz "bulunamadı" ne olduğunu
  /// anlatmıyor.
  String _messageFor(ApiException error) {
    switch (error.errorCode) {
      case 'JOB_TEMPLATE_JOB_NOT_FOUND':
        return 'Bu ilandan şablon çıkaramazsınız. Yalnızca kendi '
            'ilanlarınızdan şablon oluşturulabilir.';
      case 'JOB_TEMPLATE_NOT_FOUND':
        return 'Şablon bulunamadı. Listeyi yenileyip tekrar deneyin.';
    }
    return error.message;
  }

  void clear() {
    _generation++;
    _templates.clear();
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
