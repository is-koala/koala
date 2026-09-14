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

/// Kartta satır içi hata taşıyabilen alanlar.
enum AddressField {
  city,
  district,
  neighborhood,
  thoroughfare,
  buildingNumber,
  postalCode,
  position,
}

/// Ters geokodun neden düştüğü. Şeridin metnini ve eylemini, kaydet
/// düğmesinin açık kalıp kalmayacağını bu belirler; sunucu üç durumu üç
/// ayrı `errorCode` ile ayırıyor ve kullanıcı için üçünün çözümü farklı
/// (is-koala/koala#173).
enum ReverseGeocodeFailureKind {
  /// Pin İstanbul hizmet alanı dışında: aynı pinle tekrar denemek boş,
  /// adres de kaydedilemez; pinin taşınması gerekir.
  outsideServiceArea,

  /// Sağlayıcı bu nokta için adres bulamadı: pin geçerli, alanlar elle
  /// tamamlanır.
  noResult,

  /// Sağlayıcıya ulaşılamadı: geçici; yenilemek anlamlı, elle giriş de açık.
  providerUnavailable,

  /// Ağ, zaman aşımı ya da tanınmayan kod: genel metin, tekrar dene.
  unknown,
}

/// Düşen ters geokodun kullanıcıya söylenecek hâli.
class ReverseGeocodeFailure {
  const ReverseGeocodeFailure({required this.kind, required this.message});

  /// Sunucunun `errorCode`'undan türetir. Metin sunucununki; sunucu metin
  /// göndermediyse koda özel Türkçe yedek. Tanınmayan kod ve sunucuya hiç
  /// varmamış hatalar [ReverseGeocodeFailureKind.unknown] olur ve sabit
  /// genel cümleyi taşır — ağ hatasının kendi metni ("internet bağlantını
  /// kontrol et") pinin altındaki şeride uymuyor.
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

  /// Şeridin eylem yazısı; `null` ise şerit eylem taşımaz.
  ///
  /// Hizmet alanı dışında aynı pinle yeniden istemek bir şey değiştirmez.
  /// Sağlayıcı düştüyse "Yenile": geçici bir durum, kullanıcı biraz sonra
  /// dener. Diğerlerinde "Tekrar dene".
  String? get retryLabel => switch (kind) {
    ReverseGeocodeFailureKind.outsideServiceArea => null,
    ReverseGeocodeFailureKind.providerUnavailable => 'Yenile',
    ReverseGeocodeFailureKind.noResult ||
    ReverseGeocodeFailureKind.unknown => 'Tekrar dene',
  };

  /// Adres bu pinle kaydedilemez; kullanıcının pini taşıması gerekir.
  bool get blocksSave => kind == ReverseGeocodeFailureKind.outsideServiceArea;
}

/// Harita-öncelikli adres ekranının durumu ve iş mantığı.
///
/// Tek gerçek **pin**dir: kullanıcı haritayı kaydırıp bıraktığında kamera
/// hedefi pin olur ([cameraIdle]), pin durunca ters geokod adayı alanları
/// doldurur; arama adayı ve cihaz konumu ise pini kendileri taşır ve
/// haritadan onları izlemesi istenir ([pendingCameraTarget]). Böylece
/// haritanın gönderdiği "durdu" olayı pinle aynı noktadaysa hiçbir şey
/// yapmaz — programatik kamera hareketi ikinci bir ters geokod üretmez.
///
/// Sağlayıcı verisi yalnız aday sınırında kalır (ADR-0007): aday alanlara
/// yazılır, kullanıcı görür ve düzenler; pin elle oynadığı anda aday kanıtı
/// düşer ve kaynak `USER_CONFIRMED_PIN` olur. Sunucu aday kanıtını **pinle
/// birebir** eşleştirdiği için adayın konumu pinin kendisi olur.
class MapFirstAddressController extends ChangeNotifier {
  MapFirstAddressController({
    required AddressSearchGateway searchGateway,
    required ReferenceLocationService referenceService,
    required DeviceLocationSource locationSource,
    ConfirmedAddress? initialAddress,
    Duration reverseDebounce = defaultReverseDebounce,
    Duration autocompleteDebounce = const Duration(milliseconds: 350),
  }) : _searchGateway = searchGateway,
       _referenceService = referenceService,
       _locationSource = locationSource,
       _reverseDebounce = reverseDebounce,
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

  /// Pin durduktan sonra ters geokod isteğine kadar beklenen süre: art arda
  /// küçük düzeltmeler tek istek olsun, ama kullanıcı "bekliyor" hissetmesin.
  static const Duration defaultReverseDebounce = Duration(milliseconds: 600);

  /// Kamera hedefi pinle bu kadar yakınsa aynı nokta sayılır. Altı ondalık
  /// yuvarlamanın (~11 cm) ve harita animasyonunun kayma payından büyük,
  /// bir binanın genişliğinden küçük.
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

  /// Arama kutusunun metni.
  final TextEditingController searchText;

  ReferenceLocation? country;
  ReferenceLocation? city;
  ReferenceLocation? district;

  /// Onaylanacak konum; harita ilk kez durana kadar `null`.
  LatLng? pin;
  AddressPositionSource positionSource;
  String? candidateToken;

  /// Alanları dolduran sağlayıcının adı; aday yokken `null`.
  String? providerAttribution;
  bool candidateNeedsReview = false;

  /// Adayın bulunduğu düzey; sunucu göndermediyse ya da aday yokken `null`.
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

  /// Alanlar bir adaydan mı doldu; "Sadece pini kullan" bu durumda görünür.
  bool get hasCandidate => candidateToken != null;

  /// Aday sokak ya da mahalle düzeyinde kaldı ve bina numarası hâlâ boş:
  /// kullanıcıya "bina numarasını girin" ipucu gösterilir. Kullanıcı
  /// numarayı yazınca ipucu kalkar; pin oynayınca adayla birlikte düşer.
  bool get buildingNumberHintVisible =>
      (candidatePrecision?.lacksBuildingNumber ?? false) &&
      buildingNumber.text.trim().isEmpty;

  // ------------------------------------------------------------------ Harita

  late LatLng _cameraTarget;
  LatLng? _pendingCameraTarget;
  bool _resolvingOpeningPosition = false;

  /// Pin için ters geokod henüz istenmedi. Programatik kamera hareketinde
  /// harita "hareket" olaylarıyla zamanlayıcıyı iptal ediyor; "durdu" olayı
  /// pinle aynı noktaya gelince bu bayrak sayesinde istek yeniden kurulur.
  bool _pinNeedsReverse = false;

  /// Haritanın açıldığı nokta: düzenlenen adresin pini, yoksa şehir merkezi.
  LatLng get initialCameraTarget => pin ?? AppMap.istanbulCenter;

  /// Haritanın gitmesi istenen nokta. Sayfa okuyup kamerayı oraya taşır ve
  /// [takePendingCameraTarget] ile tüketir.
  LatLng? get pendingCameraTarget => _pendingCameraTarget;

  LatLng? takePendingCameraTarget() {
    final target = _pendingCameraTarget;
    _pendingCameraTarget = null;
    return target;
  }

  /// Kamera hareket hâlinde; her karede gelir, o yüzden dinleyici uyandırmaz.
  void cameraMoved(LatLng target) {
    _cameraTarget = target;
    _reverseTimer?.cancel();
  }

  /// Kamera durdu. Hedef pinden farklıysa pin oraya taşınır ve ters geokod
  /// zamanlanır; aynı noktadaysa (programatik hareket, açılış) pin
  /// dokunulmaz, yalnız bekleyen bir ters geokod varsa yeniden kurulur.
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
    _scheduleReverse(target);
  }

  void _scheduleReverse(LatLng target) {
    _pinNeedsReverse = true;
    _reverseTimer?.cancel();
    _reverseTimer = Timer(_reverseDebounce, () => _reverseGeocode(target));
  }

  /// Pini kullanıcı seçimi yapar: aday kanıtı düşer, kaynak elle seçime döner.
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

  /// Son ters geokod düştüyse nedeni ve metni; başarıda ve pin oynayınca
  /// `null`.
  ReverseGeocodeFailure? get reverseFailure => _reverseFailure;

  /// Kaydet düğmesinin kapalı olmasının gerekçesi; açıkken `null`.
  ///
  /// Sunucu bu pini hizmet alanı dışı saydı: aynı pinle kaydetmeyi denemek
  /// aynı `400` ile dönerdi, o yüzden düğme baştan kapalı ve yanında neden
  /// yazıyor. Hizmet alanı kutusunun kendisi değişmez.
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

  /// Başarısız ters geokodu aynı pin için yeniden dener.
  Future<void> retryReverse() async {
    final current = pin;
    if (current == null) return;
    _reverseTimer?.cancel();
    await _reverseGeocode(current);
  }

  /// Adayın doldurduğu alanları boşaltır, pini korur.
  ///
  /// İl/ilçe kalır: Koala referansından geliyor ve kullanıcının seçtiği pinin
  /// içinde bulunduğu ilçe; yanlışsa listeden değiştirilebilir. Sağlayıcının
  /// yazdığı metinler ve aday kanıtı düşer, kaynak elle seçime döner.
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

  /// Adayı alanlara yazar; kullanıcıya özel ayrıntılar (blok, bina adı, kat,
  /// daire, tarif) korunur çünkü sağlayıcı onları bilemez.
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
    positionSource = candidate.position.source;
    candidateToken = candidate.candidateToken;
    providerAttribution = candidate.attribution;
    candidateNeedsReview = candidate.needsUserReview;
    candidatePrecision = candidate.precision;
    notifyListeners();
  }

  // ------------------------------------------------------------------ Arama

  /// Arama adayını çözer, alanlara yazar ve haritayı oraya taşır.
  Future<void> selectSuggestion(AddressSuggestion suggestion) async {
    final candidate = await autocomplete.select(suggestion);
    if (_disposed || candidate == null) return;

    searchText.text = [
      suggestion.mainText,
      suggestion.secondaryText,
    ].where((value) => value.isNotEmpty).join(', ');

    // Bekleyen ters geokod adayın üstüne yazmasın.
    _reverseTimer?.cancel();
    _pinNeedsReverse = false;
    _reverseRevision++;
    _reverseGeocoding = false;
    _reverseFailure = null;

    // Harita adayı izlesin; ardından gelen "durdu" olayı pinle aynı noktada
    // olacağı için ikinci bir ters geokod üretmez.
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

  /// Konum izni alındı; harita mavi noktayı çizebilir.
  bool get locationGranted => _locationGranted;

  /// Açılışta pin yoksa ve izin **zaten** verilmişse haritayı cihaza taşır;
  /// izin yoksa haritanın açıldığı nokta pin olur. İzin istemez (ADR-0007).
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

  /// "Konumumu kullan": izni bu anda ister, konumu alır ve haritayı taşır.
  /// Başarısızsa kullanıcıya söylenecek mesajı döner; başarıda `null`.
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
          return 'Cihaz konum servisi kapalı. Pini elle seçebilirsiniz.';
        case DeviceLocationStatus.denied:
          return 'Konum izni olmadan da pini elle seçebilirsiniz.';
        case DeviceLocationStatus.unavailable:
          return 'Konum alınamadı. Pini elle seçebilirsiniz.';
      }
    } finally {
      if (!_disposed) {
        _locating = false;
        notifyListeners();
      }
    }
  }

  // -------------------------------------------------------------- Referans

  /// Ülke seçenekleri; aday gelmeden il seçmek isteyen kullanıcı için.
  Future<List<ReferenceLocation>> countryOptions() =>
      _referenceService.fetchCountries();

  /// Seçili ülkenin illeri. Ülke seçilmemişse ve tek ülke varsa onu seçer.
  Future<List<ReferenceLocation>> cityOptions() async {
    if (country == null) {
      final countries = await countryOptions();
      if (countries.length == 1) selectCountry(countries.single);
    }
    final selected = country;
    if (selected == null) return const [];
    return _referenceService.fetchCities(selected.id);
  }

  /// Seçili ilin ilçeleri; il yoksa boş.
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

  /// Kaydet denendi mi; satır içi hatalar ancak o zaman gösterilir.
  bool get validationAttempted => _validationAttempted;

  String? _validate(AddressField field) {
    switch (field) {
      case AddressField.city:
        // Ülke kartta ayrı bir alan değil; il seçilirken kendiliğinden
        // çözülüyor. O yüzden önce il istenir.
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

  /// Alanın satır içi hatası; kaydet denenmediyse ya da alan geçerliyse
  /// `null`.
  String? errorFor(AddressField field) =>
      _validationAttempted ? _validate(field) : null;

  /// Hepsi geçerliyse `null`, değilse ilk eksik alanın mesajı.
  String? get validationMessage {
    for (final field in AddressField.values) {
      final message = _validate(field);
      if (message != null) return message;
    }
    return null;
  }

  /// Kullanıcının gördüğü alanlardan kurulan onaylı adres; eksik varsa `null`.
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

  /// Kaydetme girişimi: satır içi hataları açar ve geçerliyse adresi döner.
  /// Kaydet kapalıyken ([saveBlockedReason]) hiçbir şey yapmaz; düğme zaten
  /// basılamıyor, bu yalnız programatik çağrıya karşı kapı.
  ConfirmedAddress? submit() {
    if (saveBlockedReason != null) return null;
    _validationAttempted = true;
    notifyListeners();
    return confirmed;
  }

  // --------------------------------------------------------------- Yaşam

  bool _disposed = false;

  void _textChanged() {
    // Kaydet denendikten sonra kullanıcı düzelttikçe hata satırı kalksın;
    // bina numarası ipucu da kullanıcı numarayı yazınca kalksın.
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
