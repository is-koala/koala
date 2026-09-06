import 'package:flutter/material.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/job_gallery_service.dart';

/// Tek bir ilanın galerisini ve yazma yaşam döngüsünü yönetir.
///
/// Her başarılı istekte liste bütünüyle sunucu yanıtıyla değiştirilir. Bu
/// özellikle kapak seçimi ve şirket galerisinden görsel ekleme için önemli:
/// istemci, sunucunun varsayılan kapak kararını tahmin etmez.
class JobGalleryProvider extends ChangeNotifier {
  JobGalleryProvider({JobGalleryService? service})
    : _service = service ?? JobGalleryService();

  final JobGalleryService _service;

  List<GalleryImage> _images = const [];
  String? _loadedJobId;
  String? _loadingJobId;
  bool _isLoading = false;
  bool _isBusy = false;
  bool _loadedSuccessfully = false;
  String? _errorMessage;
  int _generation = 0;
  bool _isDisposed = false;

  List<GalleryImage> get images => List.unmodifiable(_images);
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _loadedSuccessfully && _images.isEmpty;
  bool get canAddImage =>
      _loadedSuccessfully && _images.length < UploadLimits.maxGalleryImages;

  bool isLoadedFor(String jobId) =>
      _loadedJobId == jobId && !_isLoading && _loadedSuccessfully;

  Future<void> load(String jobId, {bool force = false}) async {
    if (_isLoading && _loadingJobId == jobId) return;
    if (isLoadedFor(jobId) && !force && _errorMessage == null) return;

    final generation = ++_generation;
    _isLoading = true;
    _loadingJobId = jobId;
    _errorMessage = null;
    if (_loadedJobId != jobId) {
      _loadedJobId = null;
      _images = const [];
      _loadedSuccessfully = false;
    }
    _notify();

    try {
      final images = await _service.fetchGallery(jobId);
      if (generation != _generation) return;
      _images = images;
      _loadedJobId = jobId;
      _loadedSuccessfully = true;
    } on ApiException catch (error) {
      if (generation != _generation) return;
      _errorMessage = error.message;
      _loadedJobId = jobId;
      _loadedSuccessfully = false;
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _loadingJobId = null;
        _notify();
      }
    }
  }

  Future<bool> addImage(String filePath) {
    if (!canAddImage) return Future.value(false);
    return _runWrite((jobId) => _service.addImage(jobId, filePath));
  }

  Future<bool> replaceGallery(List<GalleryImage> images) {
    if (images.length > UploadLimits.maxGalleryImages) {
      _errorMessage = 'Galeride en fazla 10 görsel olabilir';
      _notify();
      return Future.value(false);
    }
    return _runWrite((jobId) => _service.replaceGallery(jobId, images));
  }

  Future<bool> removeImage(String imageId) {
    return _runWrite((jobId) => _service.removeImage(jobId, imageId));
  }

  Future<bool> _runWrite(
    Future<List<GalleryImage>> Function(String jobId) action,
  ) async {
    final jobId = _loadedJobId;
    if (jobId == null || !_loadedSuccessfully || _isLoading || _isBusy) {
      return false;
    }

    final generation = _generation;
    _isBusy = true;
    _errorMessage = null;
    _notify();

    try {
      final images = await action(jobId);
      if (generation != _generation || _loadedJobId != jobId) return false;
      _images = images;
      return true;
    } on ApiException catch (error) {
      if (generation == _generation && _loadedJobId == jobId) {
        _errorMessage = error.message;
      }
      return false;
    } finally {
      if (generation == _generation && _loadedJobId == jobId) {
        _isBusy = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _generation++;
    super.dispose();
  }
}
