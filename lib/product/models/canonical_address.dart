import 'package:koala/product/utils/coordinate_precision.dart';

enum AddressPositionSource {
  autocompleteConfirmed('AUTOCOMPLETE_CONFIRMED'),
  reverseGeocodeConfirmed('REVERSE_GEOCODE_CONFIRMED'),
  userConfirmedPin('USER_CONFIRMED_PIN'),
  legacyUnverified('LEGACY_UNVERIFIED');

  const AddressPositionSource(this.code);

  final String code;

  static AddressPositionSource fromCode(Object? value) {
    return AddressPositionSource.values.firstWhere(
      (source) => source.code == value,
      orElse: () => AddressPositionSource.legacyUnverified,
    );
  }
}

/// Ters geokod adayının hangi düzeyde bulunduğu; sunucunun opsiyonel
/// `precision` alanı (is-koala/koala-backend#273).
///
/// Sağlayıcı bina bulamayınca sokak ya da mahalle düzeyine düşüyor ve bina
/// numarası boş geliyor; ekran buna bakarak "bina numarasını girin" ipucu
/// gösteriyor. Alan gelmezse ya da tanınmayan bir değer taşırsa `null`:
/// eski sunucuyla davranış değişmez.
enum AddressCandidatePrecision {
  building('BUILDING'),
  street('STREET'),
  neighborhood('NEIGHBORHOOD');

  const AddressCandidatePrecision(this.code);

  final String code;

  /// Bina numarası sağlayıcıdan gelmedi; kullanıcının girmesi gerekir.
  bool get lacksBuildingNumber => this != building;

  static AddressCandidatePrecision? fromCode(Object? value) {
    for (final precision in values) {
      if (precision.code == value) return precision;
    }
    return null;
  }
}

class AddressComponents {
  const AddressComponents({
    required this.neighborhood,
    required this.thoroughfare,
    required this.postalCode,
    this.siteName,
    this.block,
    this.buildingName,
    this.buildingNumber,
    this.floor,
    this.unitNumber,
    this.additionalDirections,
  });

  final String neighborhood;
  final String thoroughfare;
  final String? siteName;
  final String? block;
  final String? buildingName;
  final String? buildingNumber;
  final String? floor;
  final String? unitNumber;
  final String postalCode;
  final String? additionalDirections;

  factory AddressComponents.fromJson(Map<String, dynamic> json) {
    return AddressComponents(
      neighborhood: json['neighborhood'] as String? ?? '',
      thoroughfare: json['thoroughfare'] as String? ?? '',
      siteName: json['siteName'] as String?,
      block: json['block'] as String?,
      buildingName: json['buildingName'] as String?,
      buildingNumber: json['buildingNumber'] as String?,
      floor: json['floor'] as String?,
      unitNumber: json['unitNumber'] as String?,
      postalCode: json['postalCode'] as String? ?? '',
      additionalDirections: json['additionalDirections'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'neighborhood': neighborhood.trim(),
    'thoroughfare': thoroughfare.trim(),
    'siteName': ?_trimmed(siteName),
    'block': ?_trimmed(block),
    'buildingName': ?_trimmed(buildingName),
    'buildingNumber': ?_trimmed(buildingNumber),
    'floor': ?_trimmed(floor),
    'unitNumber': ?_trimmed(unitNumber),
    'postalCode': postalCode.trim(),
    'additionalDirections': ?_trimmed(additionalDirections),
  };
}

class AddressPosition {
  const AddressPosition({
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final double latitude;
  final double longitude;
  final AddressPositionSource source;

  factory AddressPosition.fromJson(Map<String, dynamic> json) {
    return AddressPosition(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      source: AddressPositionSource.fromCode(json['source']),
    );
  }

  /// Koordinat gövdeye altı ondalıkla yazılır: adres yazımı (`AddressWrite`)
  /// ilan, şirket ve çalışan adresinin hepsinde bu yoldan geçiyor ve sunucu
  /// `AddressPositionRequestDto` üzerinde `@Digits(fraction = 6)` uyguluyor.
  Map<String, dynamic> toJson() => {
    'latitude': CoordinatePrecision.round6(latitude),
    'longitude': CoordinatePrecision.round6(longitude),
    'source': source.code,
  };
}

class AddressWrite {
  const AddressWrite({
    required this.countryId,
    required this.cityId,
    required this.districtId,
    required this.components,
    required this.position,
    this.candidateToken,
  });

  final String countryId;
  final String cityId;
  final String districtId;
  final AddressComponents components;
  final AddressPosition position;
  final String? candidateToken;

  Map<String, dynamic> toJson() => {
    'countryId': countryId,
    'cityId': cityId,
    'districtId': districtId,
    'components': components.toJson(),
    'position': position.toJson(),
    'candidateToken': ?_trimmed(candidateToken),
  };
}

class AddressSearchSession {
  const AddressSearchSession({required this.id, required this.expiresAt});

  final String id;
  final DateTime expiresAt;

  factory AddressSearchSession.fromJson(Map<String, dynamic> json) {
    return AddressSearchSession(
      id: '${json['id']}',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class AddressSuggestion {
  const AddressSuggestion({
    required this.id,
    required this.mainText,
    required this.secondaryText,
  });

  final String id;
  final String mainText;
  final String secondaryText;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      id: '${json['id']}',
      mainText: json['mainText'] as String? ?? '',
      secondaryText: json['secondaryText'] as String? ?? '',
    );
  }
}

class AddressCandidate {
  const AddressCandidate({
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.cityId,
    required this.cityName,
    required this.districtId,
    required this.districtName,
    required this.components,
    required this.position,
    required this.candidateToken,
    required this.needsUserReview,
    required this.attribution,
    this.precision,
  });

  final String countryId;
  final String countryName;
  final String countryCode;
  final String cityId;
  final String cityName;
  final String districtId;
  final String districtName;
  final AddressComponents components;
  final AddressPosition position;
  final String candidateToken;
  final bool needsUserReview;
  final String attribution;

  /// Sunucu göndermediyse `null`; ipucu o zaman çıkmaz.
  final AddressCandidatePrecision? precision;

  factory AddressCandidate.fromJson(Map<String, dynamic> json) {
    return AddressCandidate(
      countryId: '${json['countryId']}',
      countryName: json['countryName'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      cityId: '${json['cityId']}',
      cityName: json['cityName'] as String? ?? '',
      districtId: '${json['districtId']}',
      districtName: json['districtName'] as String? ?? '',
      components: AddressComponents.fromJson(
        json['components'] as Map<String, dynamic>,
      ),
      position: AddressPosition.fromJson(
        json['position'] as Map<String, dynamic>,
      ),
      candidateToken: json['candidateToken'] as String,
      needsUserReview: json['needsUserReview'] as bool? ?? true,
      attribution: json['attribution'] as String? ?? '',
      precision: AddressCandidatePrecision.fromCode(json['precision']),
    );
  }

  AddressWrite toWrite() => AddressWrite(
    countryId: countryId,
    cityId: cityId,
    districtId: districtId,
    components: components,
    position: position,
    candidateToken: candidateToken,
  );
}

class CanonicalAddress {
  const CanonicalAddress({
    required this.id,
    required this.countryId,
    required this.countryName,
    required this.countryCode,
    required this.cityId,
    required this.cityName,
    required this.districtId,
    required this.districtName,
    required this.canonicalVersion,
    required this.needsReview,
    this.components,
    this.position,
    this.displayAddress,
    this.confirmedAt,
  });

  final String id;
  final String countryId;
  final String countryName;
  final String countryCode;
  final String cityId;
  final String cityName;
  final String districtId;
  final String districtName;
  final AddressComponents? components;
  final AddressPosition? position;
  final String? displayAddress;
  final DateTime? confirmedAt;
  final int canonicalVersion;
  final bool needsReview;

  String? get shortLabel {
    final parts = [districtName, cityName].where((value) => value.isNotEmpty);
    return parts.isEmpty ? null : parts.join('/');
  }

  factory CanonicalAddress.fromJson(Map<String, dynamic> json) {
    final components = json['components'];
    final position = json['position'];

    return CanonicalAddress(
      id: '${json['id']}',
      countryId: '${json['countryId']}',
      countryName: json['countryName'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      cityId: '${json['cityId']}',
      cityName: json['cityName'] as String? ?? '',
      districtId: '${json['districtId']}',
      districtName: json['districtName'] as String? ?? '',
      components: components is Map<String, dynamic>
          ? AddressComponents.fromJson(components)
          : null,
      position: position is Map<String, dynamic>
          ? AddressPosition.fromJson(position)
          : null,
      displayAddress: json['displayAddress'] as String?,
      confirmedAt: DateTime.tryParse(json['confirmedAt'] as String? ?? ''),
      canonicalVersion: (json['canonicalVersion'] as num?)?.toInt() ?? 0,
      needsReview: json['needsReview'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'countryId': countryId,
    'countryName': countryName,
    'countryCode': countryCode,
    'cityId': cityId,
    'cityName': cityName,
    'districtId': districtId,
    'districtName': districtName,
    'components': components?.toJson(),
    'position': position?.toJson(),
    'displayAddress': displayAddress,
    'confirmedAt': confirmedAt?.toIso8601String(),
    'canonicalVersion': canonicalVersion,
    'needsReview': needsReview,
  };
}

String? _trimmed(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
