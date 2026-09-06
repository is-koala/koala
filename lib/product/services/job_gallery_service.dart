import 'package:flutter/foundation.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// İş ilanı galerisinin ortak API sınırı.
///
/// Çalışan tarafı yalnız [fetchGallery] çağırır; işveren aynı kaynağı
/// yönetir. Bütün yazmalar galerinin sunucudaki son hâlini döndürür.
class JobGalleryService {
  JobGalleryService._(this._apiClient);

  static final JobGalleryService _instance = JobGalleryService._(ApiClient());

  factory JobGalleryService() => _instance;

  @visibleForTesting
  factory JobGalleryService.withClient(ApiClient apiClient) {
    return JobGalleryService._(apiClient);
  }

  final ApiClient _apiClient;

  Future<List<GalleryImage>> fetchGallery(String jobId) {
    return _apiClient.get<List<GalleryImage>>(
      ApiPaths.jobImages(jobId),
      parse: GalleryImage.listFromJson,
    );
  }

  Future<List<GalleryImage>> addImage(String jobId, String filePath) {
    return _apiClient.postFile<List<GalleryImage>>(
      ApiPaths.jobImages(jobId),
      fieldName: 'image',
      filePath: filePath,
      parse: GalleryImage.listFromJson,
    );
  }

  /// [images] galerinin tamamıdır; sıra listedeki konumdan yazılır.
  Future<List<GalleryImage>> replaceGallery(
    String jobId,
    List<GalleryImage> images,
  ) {
    return _apiClient.put<List<GalleryImage>>(
      ApiPaths.jobImages(jobId),
      body: {
        'images': [
          for (final (index, image) in images.indexed)
            image.toEntryJson(sortOrder: index),
        ],
      },
      parse: GalleryImage.listFromJson,
    );
  }

  Future<List<GalleryImage>> removeImage(String jobId, String imageId) {
    return _apiClient.delete<List<GalleryImage>>(
      ApiPaths.jobImage(jobId, imageId),
      parse: GalleryImage.listFromJson,
    );
  }
}
