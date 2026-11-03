import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_map.dart';
import 'package:koala/product/constants/app_map_style.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/providers/map_first_address_controller.dart';
import 'package:koala/product/services/address_search_service.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/option_sheet.dart';

part 'map_first_address_pagemodel.dart';

/// Harita-öncelikli adres ekranı: tam ekran harita, ortada sabit pin, altta
/// kayan kart.
///
/// Kullanıcı adresi, şirket adresi ve ilan adresi aynı ekranı kullanır
/// (ADR-0007). Akış: kullanıcı haritayı kaydırır, pin durunca ters geokod
/// adayı karttaki alanları doldurur, kullanıcı yalnız daire/kat/tarif ekler
/// ve **Adresi kaydet** der. Arama kutusu ve alanların elle düzenlenmesi aynı
/// kartın içinde ikincil yol olarak durur; "Sadece pini kullan" adayın
/// yazdıklarını boşaltıp pini korur.
///
/// Sonuç [ConfirmedAddress] olarak `context.pop` ile döner. [onSave]
/// verilirse geri dönmeden önce çağrılır (çalışan adresi `PUT` ile yazılır);
/// `ApiException` fırlatırsa ekran kapanmaz ve hata toast olarak gösterilir.
///
/// Açılışta konum izni **zaten** verilmişse harita cihaza gider; verilmemişse
/// düzenlenen adresin pinine, o da yoksa şehir merkezine açılır. İzin
/// diyaloğu yalnız "Konumumu kullan" düğmesinde açılır.
class MapFirstAddressPage extends StatefulWidget {
  const MapFirstAddressPage({
    super.key,
    this.title = 'Adres',
    this.initialAddress,
    this.onSave,
    this.controller,
    this.addressSearchGateway,
    this.referenceService,
    this.locationSource,
    this.reverseDebounce = MapFirstAddressController.defaultReverseDebounce,
    this.autocompleteDebounce = const Duration(milliseconds: 350),
  });

  final String title;

  /// Düzenlenen adres; harita onun pinine açılır, alanlar ondan dolar.
  final ConfirmedAddress? initialAddress;

  /// Onaylanan adresi kalıcılaştıran çağrı; `null` ise ekran yalnız adresi
  /// döndürür (ilan ve şirket formu kaydı kendisi yapar).
  final Future<void> Function(ConfirmedAddress address)? onSave;

  /// Testlerin sürmek için verdiği kontrolcü; verilmezse sayfa kendi kurar.
  final MapFirstAddressController? controller;

  final AddressSearchGateway? addressSearchGateway;
  final ReferenceLocationService? referenceService;
  final DeviceLocationSource? locationSource;
  final Duration reverseDebounce;
  final Duration autocompleteDebounce;

  @override
  State<MapFirstAddressPage> createState() => _MapFirstAddressPageState();
}

class _MapFirstAddressPageState extends MapFirstAddressPagemodel {
  /// Harita üstündeki yuvarlak düğmelerin çapı.
  static const double _overlayButtonSize = 44;

  /// Sabit pinin boyu; ucu kamera hedefine denk gelsin diye kendi boyu kadar
  /// yukarı kaydırılıyor.
  static const double _pinSize = AppSizes.mapPin;

  /// Kartın gölgesi.
  static const double _sheetShadowBlur = 16;

  /// Sağlayıcı logosunun kenarı.
  static const double _providerLogoSize = 16;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      // Klavye açılınca harita yeniden ölçülmesin; kart kendi alt payını
      // klavye kadar büyütüp kaydırılabilir kalıyor.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: mapsAvailable ? _map() : _mapPlaceholder()),
          if (mapsAvailable) _centerPin(),
          _topBar(),
          Positioned.fill(child: _card()),
        ],
      ),
    );
  }

  /// Harita anahtarı olmayan derlemede haritanın yerine geçen zemin
  /// (is-koala/koala#172). [EmptyState] kendi üst payıyla kartın üstünde
  /// kalan alana düşüyor; kart açılınca altında kalması sorun değil, kart
  /// zaten adres girişinin yolu.
  Widget _mapPlaceholder() {
    return ColoredBox(
      key: const ValueKey('map-unavailable'),
      color: context.recessedColor,
      child: const EmptyState(
        icon: AppIcons.location,
        title: 'Harita bu derlemede kullanılamıyor',
        description:
            'Adresinizi arayarak ya da il/ilçe seçip alanları doldurarak '
            'girebilirsiniz.',
      ),
    );
  }

  Widget _map() {
    return GoogleMap(
      initialCameraPosition: initialCamera,
      style: AppMapStyle.of(context),
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      myLocationEnabled: controller.locationGranted,
      myLocationButtonEnabled: false,
      cameraTargetBounds: CameraTargetBounds(AppMap.istanbulBounds),
      minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
      onMapCreated: onMapCreated,
      onCameraMove: (position) => controller.cameraMoved(position.target),
      onCameraIdle: controller.cameraIdle,
    );
  }

  /// Haritanın merkezindeki sabit pin.
  Widget _centerPin() {
    return IgnorePointer(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: _pinSize),
          child: AppIcon(
            AppIcons.location,
            size: _pinSize,
            color: AppColors.primaryColor,
            filled: true,
          ),
        ),
      ),
    );
  }

  /// Geri düğmesi, başlık ve "Konumumu kullan".
  ///
  /// Harita iki temada da açık çizdiği için üstündeki düğmelerin zemini ve
  /// yazısı temadan bağımsız sabit kalıyor.
  Widget _topBar() {
    return SafeArea(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Row(
          children: [
            _overlayButton(
              icon: AppIcons.arrowLeft,
              tooltip: 'Geri',
              onPressed: () => context.pop(),
            ),
            Expanded(
              child: Center(
                child: Container(
                  padding: AppPadding.chip,
                  decoration: BoxDecoration(
                    color: AppColors.onAccent,
                    borderRadius: AppRadius.stadiumCircular,
                    boxShadow: _overlayShadow,
                  ),
                  child: Text(
                    widget.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: AppColors.onLightSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            _overlayButton(
              icon: AppIcons.myLocation,
              tooltip: 'Konumumu kullan',
              onPressed: controller.locating ? null : useMyLocation,
              isLoading: controller.locating,
            ),
          ],
        ),
      ),
    );
  }

  List<BoxShadow> get _overlayShadow => [
    BoxShadow(
      color: AppColors.mapShadow,
      blurRadius: AppSizes.spaceSmall,
      offset: const Offset(0, 2),
    ),
  ];

  Widget _overlayButton({
    required AppIconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Material(
      color: AppColors.onAccent,
      shape: const CircleBorder(),
      shadowColor: AppColors.mapShadow,
      elevation: 2,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox.square(
            dimension: _overlayButtonSize,
            child: Center(
              child: isLoading
                  ? const SizedBox.square(
                      dimension: AppSizes.iconMedium,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryColor,
                      ),
                    )
                  : AppIcon(icon, color: AppColors.onLightSurface),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- Kart

  Widget _card() {
    return DraggableScrollableSheet(
      controller: sheetController,
      initialChildSize: MapFirstAddressPagemodel._sheetInitialSize,
      minChildSize: MapFirstAddressPagemodel._sheetMinSize,
      maxChildSize: MapFirstAddressPagemodel._sheetMaxSize,
      snap: true,
      snapSizes: const [
        MapFirstAddressPagemodel._sheetInitialSize,
        MapFirstAddressPagemodel._sheetMaxSize,
      ],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: AppRadius.sheetTop,
            boxShadow: [
              BoxShadow(
                color: AppColors.navShadow,
                blurRadius: _sheetShadowBlur,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          // Tek sütun, tembel liste değil: alanlar bir formun parçası, hepsi
          // birlikte kurulur ki odaklanma ve kaydırma tek ağaç üzerinde
          // çalışsın. Sayfa `Scaffold`'u küçülmediği için klavye payını
          // gövde ekliyor; kartın boş alanına dokunmak ya da kartı
          // sürüklemek klavyeyi kapatıyor, harita dokunuşu odağı düşürmüyor.
          child: FormPageBody(
            controller: scrollController,
            padding: AppPadding.sheet.copyWith(
              bottom: AppPadding.sheet.bottom + context.padding.bottom,
            ),
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onFocusChange: onCardFocusChanged,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _handle(),
                  const SizedBox(height: AppSizes.spaceMedium),
                  _searchSection(),
                  const SizedBox(height: AppSizes.spaceMedium),
                  ..._pinStatus(),
                  _sectionLabel('Adres bilgileri'),
                  const SizedBox(height: AppSizes.space),
                  ..._fields(),
                  const SizedBox(height: AppSizes.spaceLarge),
                  ..._saveSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _handle() {
    return Center(
      child: Container(
        width: AppSizes.sheetHandleWidth,
        height: AppSizes.sheetHandleHeight,
        decoration: BoxDecoration(
          color: context.dividerColor,
          borderRadius: AppRadius.stadiumCircular,
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  /// "Adresi kaydet" ve kapalıysa yanındaki gerekçe.
  ///
  /// Hizmet alanı dışındaki pinle düğme kapalı: sunucu aynı pini yine
  /// reddederdi. Gerekçe düğmenin altında görünür metin olarak ve düğmenin
  /// kendi semantik düğümünde ipucu olarak durur ([MyButton.semanticHint]);
  /// kullanıcı pini taşıyınca ikisi de kalkar.
  List<Widget> _saveSection() {
    final blockedReason = controller.saveBlockedReason;
    return [
      MyButton(
        key: const ValueKey('address-save'),
        onPressed: blockedReason == null ? save : null,
        title: 'Adresi kaydet',
        isLoading: isSaving,
        semanticHint: blockedReason,
      ),
      if (blockedReason != null) ...[
        const SizedBox(height: AppSizes.spaceSmall),
        Padding(
          padding: AppPadding.horizontalSmall,
          child: Text(
            blockedReason,
            key: const ValueKey('address-save-blocked-reason'),
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
      ],
    ];
  }

  // ------------------------------------------------------------------ Arama

  Widget _searchSection() {
    final search = controller.autocomplete;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyTextfield(
          labelText: 'Adres ara (mahalle, cadde, bina)',
          controller: controller.searchText,
          focusNode: searchFocus,
          keyboardType: TextInputType.streetAddress,
          onChanged: search.queryChanged,
          showSuffixIcon: true,
          suffixIcon: Padding(
            padding: AppPadding.primaryRight,
            child: AppIcon(
              AppIcons.search,
              size: AppSizes.iconMedium,
              color: context.textTertiary,
            ),
          ),
        ),
        if (search.searching || search.resolving) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          const LinearProgressIndicator(),
        ],
        if (search.errorMessage != null) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          _strip(
            mapsAvailable
                ? '${search.errorMessage} Haritada pini bırakıp alanları elle '
                      'doldurmaya devam edebilirsiniz.'
                : '${search.errorMessage} Alanları elle doldurmaya devam '
                      'edebilirsiniz.',
            actionLabel: 'Tekrar dene',
            onAction: () => search.retry(controller.searchText.text),
          ),
        ],
        if (search.suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          _suggestionList(search.suggestions, enabled: !search.resolving),
        ],
      ],
    );
  }

  Widget _suggestionList(
    List<AddressSuggestion> suggestions, {
    required bool enabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.dividerColor),
        borderRadius: AppRadius.innerCircular,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final suggestion in suggestions)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? () => selectSuggestion(suggestion) : null,
                child: Padding(
                  padding: AppPadding.infoTile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.mainText,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (suggestion.secondaryText.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.smallGap),
                        Text(
                          suggestion.secondaryText,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          Padding(padding: AppPadding.chip, child: _providerRow('Google Maps')),
        ],
      ),
    );
  }

  Widget _providerRow(String label, {Widget? trailing}) {
    return Row(
      children: [
        Image.asset(
          AppAssets.googleLogo,
          width: _providerLogoSize,
          height: _providerLogoSize,
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  // ------------------------------------------------------------- Pin durumu

  /// Pinin altında ne olduğu: öneri hazırlanıyor, öneri alınamadı ya da
  /// alanlar bir adaydan doldu.
  ///
  /// Düşen ters geokodun şeridi nedene göre değişir: metin ve eylem
  /// [ReverseGeocodeFailure]'dan gelir; hizmet alanı dışında eylem yok.
  List<Widget> _pinStatus() {
    final failure = controller.reverseFailure;
    final maplessOrigin = controller.maplessPinOrigin;
    return [
      if (maplessOrigin != null) ...[
        Text(
          _maplessPinNote(maplessOrigin),
          key: const ValueKey('mapless-pin-note'),
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
      ],
      if (controller.reverseGeocoding) ...[
        Row(
          children: [
            const SizedBox.square(
              dimension: AppSizes.iconSmall,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                'Pin için adres önerisi hazırlanıyor…',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMedium),
      ],
      if (failure != null) ...[
        _strip(
          failure.message,
          actionLabel: failure.retryLabel,
          onAction: controller.retryReverse,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
      ],
      if (controller.providerAttribution != null) ...[
        _providerRow(
          '${controller.providerAttribution} önerisi · Konumu ve adresi '
          'kontrol edin',
          trailing: TextButton(
            onPressed: controller.usePinOnly,
            child: const Text('Sadece pini kullan'),
          ),
        ),
        if (controller.candidateNeedsReview)
          Text(
            'Öneri bazı adres ayrıntılarını bulamadı; zorunlu alanları '
            'tamamlayın.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        if (controller.buildingNumberHintVisible)
          Text(
            'Öneri bina düzeyine inemedi; bina numarasını girin.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        const SizedBox(height: AppSizes.spaceMedium),
      ],
    ];
  }

  /// Haritasız kipte kaydedilecek konumun nereden geldiği. Kullanıcı pini
  /// göremediği için söylenmesi gerekiyor; şehir merkezi seçiliyken arama
  /// daha kesin bir konum verir.
  String _maplessPinNote(MaplessPinOrigin origin) => switch (origin) {
    MaplessPinOrigin.saved => 'Kayıtlı adresinizin konumu korunuyor.',
    MaplessPinOrigin.device => 'Konum cihazınızdan alındı.',
    MaplessPinOrigin.search => 'Konum arama sonucundan alındı.',
    MaplessPinOrigin.cityCenter =>
      'Konum İstanbul merkezi olarak kaydedilecek; daha kesin bir konum için '
          'adresinizi arayın ya da "Konumumu kullan" deyin.',
  };

  /// Bilgi şeridi; [actionLabel] `null` ise yalnız metin.
  Widget _strip(
    String message, {
    required String? actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: context.textTheme.bodySmall)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Alanlar

  List<Widget> _fields() {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _pickerField(
              label: 'İl *',
              value: controller.city?.name,
              onTap: pickCity,
              field: AddressField.city,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: _pickerField(
              label: 'İlçe *',
              value: controller.district?.name,
              onTap: pickDistrict,
              field: AddressField.district,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      _textField(
        label: 'Mahalle *',
        controller: controller.neighborhood,
        field: AddressField.neighborhood,
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      _textField(
        label: 'Cadde / Sokak *',
        controller: controller.thoroughfare,
        field: AddressField.thoroughfare,
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _textField(
              label: 'Bina No',
              controller: controller.buildingNumber,
              field: AddressField.buildingNumber,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: _textField(
              label: 'Site / Tesis Adı',
              controller: controller.siteName,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      Row(
        children: [
          Expanded(
            child: _textField(label: 'Blok', controller: controller.block),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: _textField(label: 'Kat', controller: controller.floor),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: _textField(
              label: 'Daire',
              controller: controller.unitNumber,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      _textField(label: 'Bina Adı', controller: controller.buildingName),
      const SizedBox(height: AppSizes.spaceMedium),
      _textField(
        label: 'Posta Kodu *',
        controller: controller.postalCode,
        field: AddressField.postalCode,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(5),
        ],
      ),
      const SizedBox(height: AppSizes.spaceMedium),
      _textField(
        label: 'Adres Tarifi',
        controller: controller.additionalDirections,
      ),
      ?_inlineError(AddressField.position),
    ];
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    AddressField? field,
    TextInputType keyboardType = TextInputType.streetAddress,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MyTextfield(
          labelText: label,
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
        ),
        if (field != null) ?_inlineError(field),
      ],
    );
  }

  /// Dokununca liste açan alan; `MyTextfield` çerçevesinde durur ki yazılan
  /// alanlarla aynı ızgarada otursun.
  Widget _pickerField({
    required String label,
    required String? value,
    required VoidCallback onTap,
    required AddressField field,
  }) {
    final hasValue = value != null && value.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.primaryCircular,
          child: Container(
            height: AppSizes.fieldHeight,
            padding: AppPadding.primaryHorizontal,
            decoration: BoxDecoration(
              border: Border.all(color: context.dividerColor),
              borderRadius: AppRadius.primaryCircular,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value : label,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: hasValue
                          ? context.textPrimary
                          : context.textSecondary,
                    ),
                  ),
                ),
                AppIcon(
                  AppIcons.chevronDown,
                  size: AppSizes.iconMedium,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
        ?_inlineError(field),
      ],
    );
  }

  /// Alanın altındaki hata satırı; kaydet denenmediyse ya da alan geçerliyse
  /// hiç çizilmez.
  Widget? _inlineError(AddressField field) {
    final message = controller.errorFor(field);
    if (message == null) return null;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppPadding.primary,
        top: AppSizes.spaceTiny,
      ),
      child: Text(
        message,
        style: context.textTheme.bodySmall?.copyWith(color: AppColors.danger),
      ),
    );
  }
}
