part of 'map_first_address_page.dart';

abstract class MapFirstAddressPagemodel extends State<MapFirstAddressPage> {
  /// Kartın açılış yüksekliği: arama kutusu, durum satırı ve ilk alanlar
  /// görünür; pin ekranın üst yarısında serbest kalır.
  static const double _sheetInitialSize = 0.42;

  /// Kart bu kadar küçülebilir: haritayı geniş görmek isteyen kullanıcı için
  /// yalnız tutamaç ve arama kutusu kalır.
  static const double _sheetMinSize = 0.18;

  /// Kart bu kadar büyüyebilir: alanlar ve kaydet düğmesi klavye açıkken de
  /// kaydırılarak erişilebilsin.
  static const double _sheetMaxSize = 0.92;

  /// Kart bir uçtan diğerine kayarken geçen süre.
  static const Duration _sheetAnimation = Duration(milliseconds: 250);

  /// Haritanın kayıtlı bir adrese ya da cihaza odaklanma süresi.
  static const Duration _cameraAnimation = Duration(milliseconds: 400);

  late final MapFirstAddressController controller;
  late final bool _ownsController;

  /// Haritanın açıldığı kare: düzenlenen adres varsa sokak ölçeğinde onun
  /// pini, yoksa şehir ölçeğinde merkez. Harita kurulduktan sonra
  /// değişmez; sonraki hareketler kameraya animasyonla verilir.
  late final CameraPosition initialCamera;
  final DraggableScrollableController sheetController =
      DraggableScrollableController();
  final FocusNode searchFocus = FocusNode();
  GoogleMapController? _mapController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    _ownsController = injected == null;
    controller =
        injected ??
        MapFirstAddressController(
          searchGateway: widget.addressSearchGateway ?? AddressSearchService(),
          referenceService:
              widget.referenceService ?? ReferenceLocationService(),
          locationSource:
              widget.locationSource ?? const GeolocatorLocationSource(),
          initialAddress: widget.initialAddress,
          reverseDebounce: widget.reverseDebounce,
          autocompleteDebounce: widget.autocompleteDebounce,
        );
    initialCamera = CameraPosition(
      target: controller.initialCameraTarget,
      zoom: controller.pin != null ? AppMap.streetZoom : AppMap.initialZoom,
    );
    controller.addListener(_onControllerChanged);
    searchFocus.addListener(_onSearchFocusChanged);
    controller.locateOnOpen();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    if (_ownsController) controller.dispose();
    searchFocus
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    sheetController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    _followPendingCamera();
  }

  /// Arama kutusu odaklanınca kart açılır ki öneri listesi klavyenin üstünde
  /// yer bulsun.
  void _onSearchFocusChanged() {
    if (searchFocus.hasFocus) expandSheet();
  }

  Future<void> expandSheet() async {
    if (!sheetController.isAttached) return;
    await sheetController.animateTo(
      _sheetMaxSize,
      duration: _sheetAnimation,
      curve: Curves.easeOut,
    );
  }

  /// Kontrolcünün istediği kamera hareketini haritaya uygular.
  ///
  /// Harita henüz kurulmadıysa hedef kontrolcüde bekler; `onMapCreated` bu
  /// metodu yeniden çağırır.
  void _followPendingCamera() {
    final mapController = _mapController;
    if (mapController == null || controller.pendingCameraTarget == null) return;
    final target = controller.takePendingCameraTarget()!;
    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(target, AppMap.streetZoom),
      duration: _cameraAnimation,
    );
  }

  void onMapCreated(GoogleMapController mapController) {
    _mapController = mapController;
    _followPendingCamera();
  }

  Future<void> useMyLocation() async {
    final message = await controller.useMyLocation();
    if (message != null && mounted) AppToast.info(context, message);
  }

  Future<void> selectSuggestion(AddressSuggestion suggestion) async {
    searchFocus.unfocus();
    await controller.selectSuggestion(suggestion);
  }

  /// İl seçtirir; ülke henüz seçilmemişse önce onu çözer.
  Future<void> pickCity() async {
    if (controller.country == null) {
      final countries = await _loadOptions(controller.countryOptions);
      if (countries == null || !mounted) return;
      if (countries.length == 1) {
        controller.selectCountry(countries.single);
      } else {
        final country = await OptionSheet.show<ReferenceLocation>(
          context,
          title: 'Ülke',
          options: countries,
          selected: controller.country,
          labelOf: (option) => option.name,
        );
        if (country == null || !mounted) return;
        controller.selectCountry(country);
      }
    }

    final cities = await _loadOptions(controller.cityOptions);
    if (cities == null || !mounted) return;
    final city = await OptionSheet.show<ReferenceLocation>(
      context,
      title: 'İl',
      options: cities,
      selected: controller.city,
      labelOf: (option) => option.name,
    );
    if (city != null) controller.selectCity(city);
  }

  Future<void> pickDistrict() async {
    if (controller.city == null) {
      AppToast.info(context, 'Önce il seçin');
      return;
    }
    final districts = await _loadOptions(controller.districtOptions);
    if (districts == null || !mounted) return;
    final district = await OptionSheet.show<ReferenceLocation>(
      context,
      title: 'İlçe',
      options: districts,
      selected: controller.district,
      labelOf: (option) => option.name,
    );
    if (district != null) controller.selectDistrict(district);
  }

  /// Referans listesini çeker; sunucu düşerse toast gösterip `null` döner.
  Future<List<ReferenceLocation>?> _loadOptions(
    Future<List<ReferenceLocation>> Function() load,
  ) async {
    try {
      return await load();
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
      return null;
    }
  }

  /// Adresi onaylar: eksik alan varsa kart açılır ve satır içi hatalar
  /// gösterilir; geçerliyse önce çağıranın kaydı, sonra geri dönüş.
  Future<void> save() async {
    if (isSaving) return;
    FocusScope.of(context).unfocus();

    final address = controller.submit();
    if (address == null) {
      await expandSheet();
      return;
    }

    final onSave = widget.onSave;
    if (onSave != null) {
      setState(() => isSaving = true);
      try {
        await onSave(address);
      } on ApiException catch (error) {
        if (mounted) AppToast.error(context, error.message);
        return;
      } finally {
        if (mounted) setState(() => isSaving = false);
      }
    }

    if (!mounted) return;
    context.pop(address);
  }
}
