import 'package:flutter/foundation.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// Ülke / il / ilçe listelerinin kaynağı (`/reference/**`).
///
/// **İki uygulama da kullanıyor:** işveren ilan açarken, çalışan adresini
/// girerken. Tek tarafa ait olmadığı için `product/` altında duruyor.
///
/// Adres yazma sözleşmesi bu kayıtların değişmeyen kimliklerini kullanıyor;
/// görünen adlar yalnızca arayüzde gösteriliyor.
///
/// Listeler nadiren değiştiği için bir kez çekilip bellekte tutuluyor.
class ReferenceLocationService {
  ReferenceLocationService._(this._apiClient);

  static final ReferenceLocationService _instance = ReferenceLocationService._(
    ApiClient(),
  );

  factory ReferenceLocationService() => _instance;

  @visibleForTesting
  factory ReferenceLocationService.withClient(ApiClient apiClient) {
    return ReferenceLocationService._(apiClient);
  }

  final ApiClient _apiClient;

  List<ReferenceLocation>? _countries;
  final Map<String, List<ReferenceLocation>> _cities = {};
  final Map<String, List<ReferenceLocation>> _districts = {};

  Future<List<ReferenceLocation>> fetchCountries() async {
    return _countries ??= await _fetchList(ApiPaths.countries);
  }

  Future<List<ReferenceLocation>> fetchCities(String countryId) async {
    return _cities[countryId] ??= await _fetchList(ApiPaths.cities(countryId));
  }

  Future<List<ReferenceLocation>> fetchDistricts(String cityId) async {
    return _districts[cityId] ??= await _fetchList(ApiPaths.districts(cityId));
  }

  Future<List<ReferenceLocation>> _fetchList(String path) {
    return _apiClient.get<List<ReferenceLocation>>(
      path,
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(ReferenceLocation.fromJson)
                .toList()
          : const [],
    );
  }
}
