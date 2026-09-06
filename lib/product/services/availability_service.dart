import 'package:flutter/foundation.dart';
import 'package:koala/product/models/availability.dart';
import 'package:koala/product/models/availability_exception.dart';
import 'package:koala/product/models/availability_slot.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Haftalık müsaitlik şablonu ve tarihe özel istisnalar.
class AvailabilityService {
  AvailabilityService._(this._apiClient);

  static final AvailabilityService _instance = AvailabilityService._(
    ApiClient(),
  );

  factory AvailabilityService() => _instance;

  @visibleForTesting
  factory AvailabilityService.withClient(ApiClient apiClient) {
    return AvailabilityService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Kullanıcının herkese açık müsaitliğini getirir.
  Future<Availability> fetchForUser(String userId) {
    return _apiClient.get<Availability>(
      ApiPaths.userAvailability(userId),
      parse: (data) => Availability.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Haftalık şablonu toptan değiştirir.
  ///
  /// Bu uç kısmi güncelleme yapmaz: sunucu önce bütün eski aralıkları siler.
  /// Çağıran, kullanıcı tek bir günü değiştirmiş olsa bile bütün haftayı
  /// [slots] içinde göndermek zorundadır.
  Future<Availability> replaceSlots(List<AvailabilitySlot> slots) {
    return _apiClient.put<Availability>(
      ApiPaths.currentUserAvailability,
      body: {'slots': slots.map((slot) => slot.toRequestJson()).toList()},
      parse: (data) => Availability.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Tarihe özel çalışabilir / çalışamaz kaydını ekler veya günceller.
  Future<AvailabilityException> saveException({
    required DateTime date,
    required bool available,
    String? note,
  }) {
    final input = AvailabilityException(
      date: date,
      available: available,
      note: note,
    );

    return _apiClient.put<AvailabilityException>(
      ApiPaths.currentUserAvailabilityExceptions,
      body: input.toRequestJson(),
      parse: (data) =>
          AvailabilityException.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Tarih istisnasını siler. Başkasının kaydı `404`.
  Future<void> deleteException(String exceptionId) {
    return _apiClient.deleteWithoutData(
      ApiPaths.currentUserAvailabilityException(exceptionId),
    );
  }
}
