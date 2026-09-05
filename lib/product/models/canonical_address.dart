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

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
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
  });

  final String countryId;
  final String cityId;
  final String districtId;
  final AddressComponents components;
  final AddressPosition position;

  Map<String, dynamic> toJson() => {
    'countryId': countryId,
    'cityId': cityId,
    'districtId': districtId,
    'components': components.toJson(),
    'position': position.toJson(),
  };
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
