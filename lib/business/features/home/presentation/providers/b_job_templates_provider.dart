import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/business/features/home/services/job_template_service.dart';
import 'package:koala/product/network/api_exception.dart';

/// İşverenin ilan şablonları.
///
/// Liste sunucuda sayfalanmıyor ve kullanıcı bazlı; bir kez çekilip uygulama
/// boyunca elde tutuluyor. Silme iyimser çalışıyor: satır dokunulduğu anda
/// kalkıyor, sunucu reddederse eski yerine geri konuyor — kaydedilen ilanlarla
/// aynı desen.
class BJobTemplatesProvider extends ChangeNotifier {
  BJobTemplatesProvider({JobTemplateService? service})
    : _service = service ?? JobTemplateService();

  final JobTemplateService _service;

  final List<JobTemplate> _templates = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  /// Çıkıştan sonra dönen istekler yeni oturumun listesine yazmasın diye.
  int _generation = 0;

  List<JobTemplate> get templates => List.unmodifiable(_templates);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  /// Son işlemin hata mesajı. Bir sonraki işlemde temizleniyor.
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

  /// Var olan bir ilandan şablon çıkarır.
  ///
  /// Başarılıysa `true` döner ve şablon listenin başına giriyor — sunucu da
  /// en yeniyi başta döndürüyor, ikinci bir okuma isteğine gerek yok.
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

  /// Şablonu siler. Reddedilirse satır eski sırasına geri konuyor.
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

  /// Sunucunun makine okunur kodunu Türkçe bir cümleye çeviriyor.
  ///
  /// Kod mesaja değil `errorCode` alanına bakılarak ayrılıyor: sunucu mesajı
  /// yerelleştiriliyor, kod sabit. Üç kodun üçü de `404` dönüyor ve düz
  /// "bulunamadı" metni kullanıcıya neyin yanlış gittiğini anlatmıyor.
  String _messageFor(ApiException error) {
    switch (error.errorCode) {
      case 'JOB_TEMPLATE_JOB_NOT_FOUND':
        return 'Bu ilandan şablon çıkaramazsınız. Yalnızca kendi '
            'ilanlarınızdan şablon oluşturulabilir.';
      case 'JOB_TEMPLATE_NOT_FOUND':
      case 'JOB_TEMPLATE_NOT_OWNER':
        return 'Şablon bulunamadı. Listeyi yenileyip tekrar deneyin.';
    }
    return error.message;
  }

  /// Çıkışta önceki kullanıcının şablonları kalmasın.
  void clear() {
    _generation++;
    _templates.clear();
    _isLoading = false;
    _hasLoaded = false;
    _errorMessage = null;
    notifyListeners();
  }
}
