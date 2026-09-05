import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_textfield.dart';

class CanonicalAddressFormController extends ChangeNotifier {
  CanonicalAddressFormController({CanonicalAddress? initialAddress})
    : initialAddress = initialAddress,
      neighborhood = TextEditingController(
        text: initialAddress?.components?.neighborhood ?? '',
      ),
      thoroughfare = TextEditingController(
        text: initialAddress?.components?.thoroughfare ?? '',
      ),
      siteName = TextEditingController(
        text: initialAddress?.components?.siteName ?? '',
      ),
      block = TextEditingController(
        text: initialAddress?.components?.block ?? '',
      ),
      buildingName = TextEditingController(
        text: initialAddress?.components?.buildingName ?? '',
      ),
      buildingNumber = TextEditingController(
        text: initialAddress?.components?.buildingNumber ?? '',
      ),
      floor = TextEditingController(
        text: initialAddress?.components?.floor ?? '',
      ),
      unitNumber = TextEditingController(
        text: initialAddress?.components?.unitNumber ?? '',
      ),
      postalCode = TextEditingController(
        text: initialAddress?.components?.postalCode ?? '',
      ),
      additionalDirections = TextEditingController(
        text: initialAddress?.components?.additionalDirections ?? '',
      ),
      position = initialAddress?.position == null
          ? null
          : LatLng(
              initialAddress!.position!.latitude,
              initialAddress.position!.longitude,
            ) {
    for (final textController in _textControllers) {
      textController.addListener(_changed);
    }
  }

  final CanonicalAddress? initialAddress;
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

  ReferenceLocation? country;
  ReferenceLocation? city;
  ReferenceLocation? district;
  LatLng? position;

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

  String? get validationMessage {
    if (country == null) return 'Ülke seçin';
    if (city == null) return 'İl seçin';
    if (district == null) return 'İlçe seçin';
    if (neighborhood.text.trim().isEmpty) return 'Mahalle zorunlu';
    if (thoroughfare.text.trim().isEmpty) return 'Cadde veya sokak zorunlu';
    if (buildingNumber.text.trim().isEmpty && siteName.text.trim().isEmpty) {
      return 'Bina numarası veya site/tesis adı zorunlu';
    }
    if (!RegExp(r'^\d{5}$').hasMatch(postalCode.text.trim())) {
      return 'Posta kodu 5 haneli olmalı';
    }
    if (position == null) return 'Konumu haritada onaylayın';
    return null;
  }

  AddressWrite? get value {
    if (validationMessage != null) return null;

    return AddressWrite(
      countryId: country!.id,
      cityId: city!.id,
      districtId: district!.id,
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
        latitude: position!.latitude,
        longitude: position!.longitude,
        source: AddressPositionSource.userConfirmedPin,
      ),
    );
  }

  void selectCountry(ReferenceLocation value) {
    country = value;
    city = null;
    district = null;
    _changed();
  }

  void selectCity(ReferenceLocation value) {
    city = value;
    district = null;
    _changed();
  }

  void selectDistrict(ReferenceLocation value) {
    district = value;
    _changed();
  }

  void selectPosition(LatLng value) {
    position = value;
    _changed();
  }

  void _changed() => notifyListeners();

  @override
  void dispose() {
    for (final textController in _textControllers) {
      textController.removeListener(_changed);
      textController.dispose();
    }
    super.dispose();
  }
}

class CanonicalAddressForm extends StatefulWidget {
  const CanonicalAddressForm({
    super.key,
    required this.controller,
    required this.pickPosition,
    this.referenceService,
  });

  final CanonicalAddressFormController controller;
  final Future<LatLng?> Function(LatLng? initialPosition) pickPosition;
  final ReferenceLocationService? referenceService;

  @override
  State<CanonicalAddressForm> createState() => _CanonicalAddressFormState();
}

class _CanonicalAddressFormState extends State<CanonicalAddressForm> {
  late final ReferenceLocationService _referenceService;
  List<ReferenceLocation> _countries = const [];
  List<ReferenceLocation> _cities = const [];
  List<ReferenceLocation> _districts = const [];
  bool _loading = true;
  bool _loadingCities = false;
  bool _loadingDistricts = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _referenceService = widget.referenceService ?? ReferenceLocationService();
    widget.controller.addListener(_refresh);
    _loadReferences();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadReferences() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final countries = await _referenceService.fetchCountries();
      if (!mounted) return;
      setState(() => _countries = countries);

      final initial = widget.controller.initialAddress;
      final country =
          _findById(countries, initial?.countryId) ??
          (countries.length == 1 ? countries.first : null);
      if (country != null) await _selectCountry(country, preserveInitial: true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectCountry(
    ReferenceLocation country, {
    bool preserveInitial = false,
  }) async {
    widget.controller.selectCountry(country);
    setState(() {
      _cities = const [];
      _districts = const [];
      _loadingCities = true;
    });

    try {
      final cities = await _referenceService.fetchCities(country.id);
      if (!mounted) return;
      setState(() => _cities = cities);
      if (preserveInitial) {
        final city = _findById(
          cities,
          widget.controller.initialAddress?.cityId,
        );
        if (city != null) await _selectCity(city, preserveInitial: true);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _selectCity(
    ReferenceLocation city, {
    bool preserveInitial = false,
  }) async {
    widget.controller.selectCity(city);
    setState(() {
      _districts = const [];
      _loadingDistricts = true;
    });

    try {
      final districts = await _referenceService.fetchDistricts(city.id);
      if (!mounted) return;
      setState(() => _districts = districts);
      if (preserveInitial) {
        final district = _findById(
          districts,
          widget.controller.initialAddress?.districtId,
        );
        if (district != null) widget.controller.selectDistrict(district);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _loadingDistricts = false);
    }
  }

  static ReferenceLocation? _findById(
    List<ReferenceLocation> options,
    String? id,
  ) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          _errorStrip(_errorMessage!),
          const SizedBox(height: AppSizes.spaceMedium),
        ],
        _referenceField(
          label: 'Ülke *',
          value: widget.controller.country?.name,
          options: _countries,
          onSelected: _selectCountry,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        _referenceField(
          label: 'İl *',
          value: widget.controller.city?.name,
          options: _cities,
          isLoading: _loadingCities,
          onSelected: _selectCity,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        _referenceField(
          label: 'İlçe *',
          value: widget.controller.district?.name,
          options: _districts,
          isLoading: _loadingDistricts,
          onSelected: widget.controller.selectDistrict,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Mahalle *',
          controller: widget.controller.neighborhood,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Cadde / Sokak *',
          controller: widget.controller.thoroughfare,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Bina No',
          controller: widget.controller.buildingNumber,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Site / Tesis Adı',
          controller: widget.controller.siteName,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Row(
          children: [
            Expanded(
              child: MyTextfield(
                labelText: 'Blok',
                controller: widget.controller.block,
              ),
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: MyTextfield(
                labelText: 'Kat',
                controller: widget.controller.floor,
              ),
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: MyTextfield(
                labelText: 'Daire',
                controller: widget.controller.unitNumber,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Bina Adı',
          controller: widget.controller.buildingName,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Posta Kodu *',
          controller: widget.controller.postalCode,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        MyTextfield(
          labelText: 'Adres Tarifi',
          controller: widget.controller.additionalDirections,
          keyboardType: TextInputType.streetAddress,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        _positionField(),
      ],
    );
  }

  Widget _errorStrip(String message) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Row(
        children: [
          Expanded(child: Text(message, style: context.textTheme.bodyMedium)),
          TextButton(onPressed: _loadReferences, child: const Text('Yenile')),
        ],
      ),
    );
  }

  Widget _referenceField({
    required String label,
    required String? value,
    required List<ReferenceLocation> options,
    required ValueChanged<ReferenceLocation> onSelected,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: options.isEmpty
          ? null
          : () => _showOptions(label, options, onSelected),
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
                value ?? label,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: value == null
                      ? context.textSecondary
                      : context.textPrimary,
                ),
              ),
            ),
            if (isLoading)
              const SizedBox.square(
                dimension: AppSizes.iconMedium,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              AppIcon(AppIcons.arrowRight, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _showOptions(
    String title,
    List<ReferenceLocation> options,
    ValueChanged<ReferenceLocation> onSelected,
  ) async {
    final picked = await AppBottomSheet.show<ReferenceLocation>(
      context,
      builder: (sheetContext) => AppBottomSheet(
        title: title,
        child: Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (_, index) => ListTile(
              title: Text(options[index].name),
              onTap: () => Navigator.pop(sheetContext, options[index]),
            ),
          ),
        ),
      ),
    );
    if (picked != null) onSelected(picked);
  }

  Widget _positionField() {
    final position = widget.controller.position;
    return InkWell(
      onTap: () async {
        final picked = await widget.pickPosition(position);
        if (picked != null) widget.controller.selectPosition(picked);
      },
      borderRadius: AppRadius.primaryCircular,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: AppSizes.fieldHeight),
        padding: AppPadding.primaryHorizontal,
        decoration: BoxDecoration(
          border: Border.all(
            color: position == null
                ? context.accentColor
                : context.dividerColor,
          ),
          borderRadius: AppRadius.primaryCircular,
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.location, color: context.accentColor),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                position == null
                    ? 'Konumu haritada onayla *'
                    : 'Konum onaylandı',
                style: context.textTheme.bodyLarge,
              ),
            ),
            AppIcon(AppIcons.arrowRight, color: context.textTertiary),
          ],
        ),
      ),
    );
  }
}
