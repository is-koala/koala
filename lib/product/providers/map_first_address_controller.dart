import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_map.dart';
import 'package:koala/product/models/address_reverse_error_codes.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/providers/address_autocomplete_controller.dart';
import 'package:koala/product/services/address_search_service.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';

enum AddressField {
  city,
  district,
  neighborhood,
  thoroughfare,
  buildingNumber,
  postalCode,
  position,
}

/// Ters geokodun neden düştüğü; sunucu üç durumu ayrı `errorCode` ile veriyor
/// ve çözümleri farklı (#173).
enum ReverseGeocodeFailureKind {
  /// Pin hizmet alanı dışında: adres kaydedilemez, pin taşınmalı.
  outsideServiceArea,

  /// Adres bulunamadı: pin geçerli, alanlar elle.
  noResult,

  /// Geçici; yenilemek anlamlı.
  providerUnavailable,

  /// Ağ, zaman aşımı ya da tanınmayan kod.
  unknown,
}

class ReverseGeocodeFailure {
  const ReverseGeocodeFailure({required this.kind, required this.message});

  /// `errorCode`'dan türetir; metin sunucunun, yoksa Türkçe yedek. Ağ hatasının
  /// kendi metni pinin altındaki şeride uymadığı için sabit cümle.
  factory ReverseGeocodeFailure.of(ApiException error) {
    final kind = switch (error.errorCode) {
      AddressReverseErrorCodes.outsideServiceArea =>
        ReverseGeocodeFailureKind.outsideServiceArea,
      AddressReverseErrorCodes.noResult => ReverseGeocodeFailureKind.noResult,
      AddressReverseErrorCodes.providerUnavailable =>
        ReverseGeocodeFailureKind.providerUnavailable,
      _ => ReverseGeocodeFailureKind.unknown,
    };
    final serverMessage = error.message.trim();
    final useServerMessage =
        kind != ReverseGeocodeFailureKind.unknown && serverMessage.isNotEmpty;
    return ReverseGeocodeFailure(
      kind: kind,
      message: useServerMessage ? serverMessage : _fallbackMessages[kind]!,
    );
  }

  static const Map<ReverseGeocodeFailureKind, String> _fallbackMessages = {
    ReverseGeocodeFailureKind.outsideServiceArea:
        'Şimdilik yalnız İstanbul içinde adres kaydedilebiliyor; pini '
        "İstanbul'a taşıyın.",
    ReverseGeocodeFailureKind.noResult:
        'Bu konum için adres bulunamadı. Pini koruduk; adresi elle '
        'tamamlayabilirsiniz.',
    ReverseGeocodeFailureKind.providerUnavailable:
        'Adres servisi şu an yanıt vermiyor; birazdan yeniden deneyin.',
    ReverseGeocodeFailureKind.unknown:
        'Bu konum için adres önerisi alınamadı. Pini koruduk; adresi elle '
        'doldurabilirsiniz.',
  };

  final ReverseGeocodeFailureKind kind;
  final String message;

  /// `null` ise şerit eylem taşımaz; hizmet alanı dışında yeniden istemek bir
  /// şey değiştirmez.
  String? get retryLabel => switch (kind) {
    ReverseGeocodeFailureKind.outsideServiceArea => null,
    ReverseGeocodeFailureKind.providerUnavailable => 'Yenile',
    ReverseGeocodeFailureKind.noResult ||
    ReverseGeocodeFailureKind.unknown => 'Tekrar dene',
  };

  bool get blocksSave => kind == ReverseGeocodeFailureKind.outsideServiceArea;
}

/// Haritasız kipte pinin kaynağı (#172).
enum MaplessPinOrigin { saved, device, search, cityCenter }

/// Harita-öncelikli adres ekranının durumu.
///
/// Tek gerçek **pin**: kullanıcı haritayı bırakınca kamera hedefi pin olur
/// ([cameraIdle]) ve ters geokod alanları doldurur. Arama ve cihaz konumu pini
/// kendileri taşır ([pendingCameraTarget]); programatik hareket ikinci bir ters
/// geokod üretmez. Pin elle oynayınca aday kanıtı düşer (ADR-0007).
class MapFirstAddressController extends ChangeNotifier {
  MapFirstAddressController({
    required AddressSearchGateway searchGateway,
    required this._referenceService,
    required this._locationSource,
    ConfirmedAddress? initialAddress,
    this._reverseDebounce = defaultReverseDebounce,
    Duration autocompleteDebounce = const Duration(milliseconds: 350),
  }) : _searchGateway = searchGateway,
       neighborhood = TextEditingController(
         text: initialAddress?.components.neighborhood ?? '',
       ),
       thoroughfare = TextEditingController(
         text: initialAddress?.components.thoroughfare ?? '',
       ),
       siteName = TextEditingController(
         text: initialAddress?.components.siteName ?? '',
       ),
       block = TextEditingController(
         text: initialAddress?.components.block ?? '',
       ),
       buildingName = TextEditingController(
         text: initialAddress?.components.buildingName ?? '',
       ),
       buildingNumber = TextEditingController(
         text: initialAddress?.components.buildingNumber ?? '',
       ),
       floor = TextEditingController(
         text: initialAddress?.components.floor ?? '',
       ),
       unitNumber = TextEditingController(
         text: initialAddress?.components.unitNumber ?? '',
       ),
       postalCode = TextEditingController(
         text: initialAddress?.components.postalCode ?? '',
       ),
       additionalDirections = TextEditingController(
         text: initialAddress?.components.additionalDirections ?? '',
       ),
       searchText = TextEditingController(),
       country = initialAddress?.country,
       city = initialAddress?.city,
       district = initialAddress?.district,
       pin = initialAddress == null
           ? null
           : LatLng(
               initialAddress.position.latitude,
               initialAddress.position.longitude,
             ),
       positionSource = initialAddress?.candidateToken == null
           ? AddressPositionSource.userConfirmedPin
           : initialAddress!.position.source,
       candidateToken = initialAddress?.candidateToken {
    _cameraTarget = initialCameraTarget;
    autocomplete = AddressAutocompleteController(
      gateway: searchGateway,
      debounce: autocompleteDebounce,
    )..addListener(notifyListeners);
    for (final textController in _textControllers) {
      textController.addListener(_textChanged);
    }
  }

  /// Art arda küçük düzeltmeler tek istek olsun, ama bekleme hissedilmesin.
  static const Duration defaultReverseDebounce = Duration(milliseconds: 600);

  /// Altı ondalık yuvarlamadan ve animasyon kaymasından büyük, bir binadan
  /// küçük.
  static const double _samePointTolerance = 0.00001;

  final AddressSearchGateway _searchGateway;
  final ReferenceLocationService _referenceService;
  final DeviceLocationSource _locationSource;
  final Duration _reverseDebounce;

  // ------------------------------------------------------------------ Alanlar

  final TextEditingController neighborhood;
  final TextEditingController thoroughfare;
  final TextEditingController siteName;
  final TextEditingController block;
  final TextEditingController buildingName;
  final TextEditingController buildingNumber;
  final TextEditingController floor;
  final TextEditingController unitNumber;
  final TextEditingController postalCode;
  final TextEditingController additionalDirections;

  final TextEditingController searchText;

  ReferenceLocation? country;
  ReferenceLocation? city;
  ReferenceLocation? district;

  /// İlk durana kadar `null`.
  LatLng? pin;
  AddressPositionSource positionSource;
  String? candidateToken;

  String? providerAttribution;
  bool candidateNeedsReview = false;

  AddressCandidatePrecision? candidatePrecision;

  late final AddressAutocompleteController autocomplete;

  List<TextEditingController> get _textControllers => [
    neighborhood,
    thoroughfare,
    siteName,
    block,
    buildingName,
    buildingNumber,
    floor,
    unitNumber,
    postalCode,
    additionalDirections,
  ];

  bool get hasCandidate => candidateToken != null;

  /// Aday sokak/mahalle düzeyinde ve bina numarası boş: ipucu gösterilir.
  bool get buildingNumberHintVisible =>
      (candidatePrecision?.lacksBuildingNumber ?? false) &&
      buildingNumber.text.trim().isEmpty;

  // ------------------------------------------------------------------ Harita

  late LatLng _cameraTarget;
  LatLng? _pendingCameraTarget;
  bool _resolvingOpeningPosition = false;

  /// Programatik harekette harita zamanlayıcıyı iptal ediyor; "durdu" pinle
  /// aynı noktaya gelince istek bu bayrakla yeniden kurulur.
  bool _pinNeedsReverse = false;

  LatLng get initialCameraTarget => pin ?? AppMap.istanbulCenter;

  // ------------------------------------------------------------ Harita yok

  bool _mapless = false;
  MaplessPinOrigin? _maplessPinOrigin;

  /// Haritasız kip: kamera olayı ve ters geokod yok.
  bool get mapless => _mapless;

  MaplessPinOrigin? get maplessPinOrigin => _mapless ? _maplessPinOrigin : null;

  /// Haritasız açılış (#172): pin kayıtlı adresten, izin varsa cihazdan, yoksa
  /// şehir merkezinden. Kullanıcı pini göremediği için ters geokod **atlanır**.
  Future<void> openWithoutMap() async {
    _mapless = true;
    if (pin != null) {
      _maplessPinOrigin = MaplessPinOrigin.saved;
      notifyListeners();
      return;
    }

    final located = await _locationSource.currentIfGranted();
    if (_disposed) return;

    if (located != null) _locationGranted = true;
    final usable = located != null && AppMap.istanbulBounds.contains(located);
    _maplessPinOrigin = usable
        ? MaplessPinOrigin.device
        : MaplessPinOrigin.cityCenter;
    _cameraTarget = usable ? located : AppMap.istanbulCenter;
    _selectPin(_cameraTarget);
  }

  /// Sayfa okuyup kamerayı taşır ve [takePendingCameraTarget] ile tüketir.
  LatLng? get pendingCameraTarget => _pendingCameraTarget;

  LatLng? takePendingCameraTarget() {
    final target = _pendingCameraTarget;
    _pendingCameraTarget = null;
    return target;
  }

  /// Her karede gelir; dinleyici uyandırmaz.
  void cameraMoved(LatLng target) {
    _cameraTarget = target;
    _reverseTimer?.cancel();
  }

  /// Kamera durdu. Hedef pinden farklıysa pin taşınır ve ters geokod
  /// zamanlanır; aynıysa yalnız bekleyen istek yeniden kurulur.
  void cameraIdle() {
    if (_resolvingOpeningPosition) return;
    final current = pin;
    if (current != null && _samePoint(current, _cameraTarget)) {
      if (_pinNeedsReverse) _scheduleReverse(current);
      return;
    }
    _settleAt(_cameraTarget);
  }

  void _moveCameraTo(LatLng target) {
    _cameraTarget = target;
    _pendingCameraTarget = target;
    _settleAt(target);
  }

  void _settleAt(LatLng target) {
    _selectPin(target);
    if (_mapless) {
      // Kullanıcı pini göremediği için ters geokod yok.
      _maplessPinOrigin = MaplessPinOrigin.device;
      notifyListeners();
      return;
    }
    _scheduleReverse(target);
  }

  void _scheduleReverse(LatLng target) {
    _pinNeedsReverse = true;
    _reverseTimer?.cancel();
    _reverseTimer = Timer(_reverseDebounce, () => _reverseGeocode(target));
  }

  /// Elle seçim: aday kanıtı düşer.
  void _selectPin(LatLng target) {
    pin = target;
    positionSource = AddressPositionSource.userConfirmedPin;
    candidateToken = null;
    providerAttribution = null;
    candidateNeedsReview = false;
    candidatePrecision = null;
    _reverseRevision++;
    _reverseFailure = null;
    notifyListeners();
  }

  static bool _samePoint(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < _samePointTolerance &&
      (a.longitude - b.longitude).abs() < _samePointTolerance;

  // ------------------------------------------------------------ Ters geokod

  Timer? _reverseTimer;
  int _reverseRevision = 0;
  bool _reverseGeocoding = false;
  ReverseGeocodeFailure? _reverseFailure;

  bool get reverseGeocoding => _reverseGeocoding;

  ReverseGeocodeFailure? get reverseFailure => _reverseFailure;

  /// Sunucu pini hizmet alanı dışı saydı; aynı pinle kaydetmek aynı `400`'ü
  /// verir, o yüzden düğme kapalı.
  String? get saveBlockedReason => (_reverseFailure?.blocksSave ?? false)
      ? 'Kaydetmek için pini İstanbul içine taşıyın.'
      : null;

  Future<void> _reverseGeocode(LatLng target) async {
    _pinNeedsReverse = false;
    final revision = ++_reverseRevision;
    _reverseGeocoding = true;
    _reverseFailure = null;
    notifyListeners();

    try {
      final candidate = await _searchGateway.reverse(
        target.latitude,
        target.longitude,
      );
      if (_disposed || revision != _reverseRevision) return;
      _applyCandidate(candidate);
    } on ApiException catch (error) {
      if (_disposed || revision != _reverseRevision) return;
      _reverseFailure = ReverseGeocodeFailure.of(error);
    } finally {
      if (!_disposed && revision == _reverseRevision) {
        _reverseGeocoding = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryReverse() async {
    final current = pin;
    if (current == null) return;
    _reverseTimer?.cancel();
    await _reverseGeocode(current);
  }

  /// Adayın doldurduğu metinleri boşaltır, pini korur. İl/ilçe referanstan
  /// geldiği için kalır.
  void usePinOnly() {
    neighborhood.clear();
    thoroughfare.clear();
    siteName.clear();
    buildingNumber.clear();
    postalCode.clear();
    positionSource = AddressPositionSource.userConfirmedPin;
    candidateToken = null;
    providerAttribution = null;
    candidateNeedsReview = false;
    candidatePrecision = null;
    notifyListeners();
  }

  /// Kullanıcıya özel ayrıntılar (kat, daire, tarif) korunur.
  void _applyCandidate(AddressCandidate candidate) {
    country = ReferenceLocation(
      id: candidate.countryId,
      name: candidate.countryName,
      code: candidate.countryCode,
    );
    city = ReferenceLocation(id: candidate.cityId, name: candidate.cityName);
    district = ReferenceLocation(
      id: candidate.districtId,
      name: candidate.districtName,
    );
    neighborhood.text = candidate.components.neighborhood;
    thoroughfare.text = candidate.components.thoroughfare;
    siteName.text = candidate.components.siteName ?? '';
    buildingNumber.text = candidate.components.buildingNumber ?? '';
    postalCode.text = candidate.components.postalCode;
    pin = LatLng(candidate.position.latitude, candidate.position.longitude);
    if (_mapless) _maplessPinOrigin = MaplessPinOrigin.search;
    positionSource = candidate.position.source;
    candidateToken = candidate.candidateToken;
    providerAttribution = candidate.attribution;
    candidateNeedsReview = candidate.needsUserReview;
    candidatePrecision = candidate.precision;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Arama

  Future<void> selectSuggestion(AddressSuggestion suggestion) async {
    final candidate = await autocomplete.select(suggestion);
    if (_disposed || candidate == null) return;

    searchText.text = [
      suggestion.mainText,
      suggestion.secondaryText,
    ].where((value) => value.isNotEmpty).join(', ');

    _reverseTimer?.cancel();
    _pinNeedsReverse = false;
    _reverseRevision++;
    _reverseGeocoding = false;
    _reverseFailure = null;

    // Harita adayı izlesin; ardından gelen "durdu" ikinci istek üretmez.
    final target = LatLng(
      candidate.position.latitude,
      candidate.position.longitude,
    );
    _cameraTarget = target;
    _pendingCameraTarget = target;
    _applyCandidate(candidate);
  }

  // ----------------------------------------------------------- Cihaz konumu

  bool _locating = false;
  bool _locationGranted = false;

  bool get locating => _locating;

  bool get locationGranted => _locationGranted;

  /// Açılışta pin yoksa ve izin **zaten** varsa haritayı cihaza taşır; izin
  /// istemez (ADR-0007).
  Future<void> locateOnOpen() async {
    if (pin != null) return;

    _resolvingOpeningPosition = true;
    LatLng? located;
    try {
      located = await _locationSource.currentIfGranted();
    } finally {
      _resolvingOpeningPosition = false;
    }
    if (_disposed) return;

    if (located != null) _locationGranted = true;
    if (located != null && AppMap.istanbulBounds.contains(located)) {
      _moveCameraTo(located);
    } else {
      _settleAt(_cameraTarget);
    }
  }

  /// "Konumumu kullan": izni ister ve haritayı taşır. Başarısızsa mesaj döner.
  Future<String?> useMyLocation() async {
    if (_locating) return null;
    _locating = true;
    notifyListeners();

    try {
      final result = await _locationSource.requestCurrent();
      if (_disposed) return null;

      switch (result.status) {
        case DeviceLocationStatus.located:
          _locationGranted = true;
          final position = result.position!;
          if (!AppMap.istanbulBounds.contains(position)) {
            return 'Koala şu anda yalnızca İstanbul içinde hizmet veriyor.';
          }
          _moveCameraTo(position);
          return null;
        case DeviceLocationStatus.serviceDisabled:
          return _mapless
              ? 'Cihaz konum servisi kapalı. Adresinizi arayarak '
                    'girebilirsiniz.'
              : 'Cihaz konum servisi kapalı. Pini elle seçebilirsiniz.';
        case DeviceLocationStatus.denied:
          return _mapless
              ? 'Konum izni olmadan da adresinizi arayarak girebilirsiniz.'
              : 'Konum izni olmadan da pini elle seçebilirsiniz.';
        case DeviceLocationStatus.unavailable:
          return _mapless
              ? 'Konum alınamadı. Adresinizi arayarak girebilirsiniz.'
              : 'Konum alınamadı. Pini elle seçebilirsiniz.';
      }
    } finally {
      if (!_disposed) {
        _locating = false;
        notifyListeners();
      }
    }
  }

  // -------------------------------------------------------------- Referans

  Future<List<ReferenceLocation>> countryOptions() =>
      _referenceService.fetchCountries();

  /// Ülke seçilmemişse ve tek ülke varsa onu seçer.
  Future<List<ReferenceLocation>> cityOptions() async {
    if (country == null) {
      final countries = await countryOptions();
      if (countries.length == 1) selectCountry(countries.single);
    }
    final selected = country;
    if (selected == null) return const [];
    return _referenceService.fetchCities(selected.id);
  }

  Future<List<ReferenceLocation>> districtOptions() async {
    final selected = city;
    if (selected == null) return const [];
    return _referenceService.fetchDistricts(selected.id);
  }

  void selectCountry(ReferenceLocation value) {
    if (country == value) return;
    country = value;
    city = null;
    district = null;
    notifyListeners();
  }

  void selectCity(ReferenceLocation value) {
    if (city == value) return;
    city = value;
    district = null;
    notifyListeners();
  }

  void selectDistrict(ReferenceLocation value) {
    district = value;
    notifyListeners();
  }

  // -------------------------------------------------------------- Doğrulama

  bool _validationAttempted = false;

  /// Satır içi hatalar ancak kaydet denenince görünür.
  bool get validationAttempted => _validationAttempted;

  String? _validate(AddressField field) {
    switch (field) {
      case AddressField.city:
        // Ülke il seçilirken çözüldüğü için önce il istenir.
        if (city == null) return 'İl seçin';
        if (country == null) return 'Ülke seçin';
        return null;
      case AddressField.district:
        return district == null ? 'İlçe seçin' : null;
      case AddressField.neighborhood:
        return neighborhood.text.trim().isEmpty ? 'Mahalle zorunlu' : null;
      case AddressField.thoroughfare:
        return thoroughfare.text.trim().isEmpty
            ? 'Cadde veya sokak zorunlu'
            : null;
      case AddressField.buildingNumber:
        return buildingNumber.text.trim().isEmpty &&
                siteName.text.trim().isEmpty
            ? 'Bina numarası veya site/tesis adı zorunlu'
            : null;
      case AddressField.postalCode:
        return RegExp(r'^\d{5}$').hasMatch(postalCode.text.trim())
            ? null
            : 'Posta kodu 5 haneli olmalı';
      case AddressField.position:
        return pin == null ? 'Konumu haritada onaylayın' : null;
    }
  }

  String? errorFor(AddressField field) =>
      _validationAttempted ? _validate(field) : null;

  String? get validationMessage {
    for (final field in AddressField.values) {
      final message = _validate(field);
      if (message != null) return message;
    }
    return null;
  }

  ConfirmedAddress? get confirmed {
    if (validationMessage != null) return null;

    return ConfirmedAddress(
      country: country!,
      city: city!,
      district: district!,
      components: AddressComponents(
        neighborhood: neighborhood.text,
        thoroughfare: thoroughfare.text,
        siteName: siteName.text,
        block: block.text,
        buildingName: buildingName.text,
        buildingNumber: buildingNumber.text,
        floor: floor.text,
        unitNumber: unitNumber.text,
        postalCode: postalCode.text,
        additionalDirections: additionalDirections.text,
      ),
      position: AddressPosition(
        latitude: pin!.latitude,
        longitude: pin!.longitude,
        source: positionSource,
      ),
      candidateToken: candidateToken,
    );
  }

  /// Hataları açar ve geçerliyse adresi döner. Kaydet kapalıyken bir şey
  /// yapmaz.
  ConfirmedAddress? submit() {
    if (saveBlockedReason != null) return null;
    _validationAttempted = true;
    notifyListeners();
    return confirmed;
  }

  // --------------------------------------------------------------- Yaşam

  bool _disposed = false;

  void _textChanged() {
    // Hata satırı ve bina numarası ipucu kullanıcı düzelttikçe kalksın.
    if (_validationAttempted || candidatePrecision != null) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reverseTimer?.cancel();
    autocomplete
      ..removeListener(notifyListeners)
      ..dispose();
    for (final textController in _textControllers) {
      textController
        ..removeListener(_textChanged)
        ..dispose();
    }
    searchText.dispose();
    super.dispose();
  }
}
