import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

/// Kullanıcının adresi.
///
/// İlana başvurabilmenin ikinci şartı: adresi olmayan kullanıcının başvurusu
/// `APPLICANT_ADDRESS_REQUIRED` ile reddediliyor. Sözleşme ve ödeme için
/// gerekiyor.
///
/// Uç toptan yazıyor (`PUT`), yani form mevcut değerlerle açılıyor ve
/// gönderilmeyen alan siliniyor. Koordinat **zorunlu**; haritadan seçiliyor.
class AddressPage extends StatefulWidget {
  const AddressPage({super.key, required this.user});

  final CurrentUser user;

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final UserService _userService = UserService();
  final ReferenceLocationService _referenceService = ReferenceLocationService();

  late final TextEditingController _addressLine;
  late final TextEditingController _postalCode;

  List<ReferenceLocation> _countries = const [];
  List<ReferenceLocation> _cities = const [];
  List<ReferenceLocation> _districts = const [];

  ReferenceLocation? _country;
  ReferenceLocation? _city;
  ReferenceLocation? _district;

  LatLng? _location;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final address = widget.user.address;
    _addressLine = TextEditingController(text: address?.addressLine ?? '');
    _postalCode = TextEditingController(text: address?.postalCode ?? '');

    final latitude = address?.latitude;
    final longitude = address?.longitude;
    if (latitude != null && longitude != null) {
      _location = LatLng(latitude, longitude);
    }

    _loadReferences();
  }

  @override
  void dispose() {
    _addressLine.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  /// Sunucunun zorunlu tuttukları: ülke, il, açık adres ve koordinat.
  bool get _canSave =>
      _country != null &&
      _city != null &&
      _addressLine.text.trim().isNotEmpty &&
      _location != null;

  /// Ülke listesini çeker ve kullanıcının kayıtlı adresini seçili getirir.
  ///
  /// Adres **ad** olarak saklanıyor (`cityName`), kimlik olarak değil; o
  /// yüzden eşleştirme ada göre yapılıyor. Ad tutmazsa alan boş açılıyor,
  /// yanlış bir seçim gösterilmiyor.
  Future<void> _loadReferences() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final countries = await _referenceService.fetchCountries();
      if (!mounted) return;

      final address = widget.user.address;
      final country = _findByName(countries, address?.countryName);
      setState(() {
        _countries = countries;
        _country = country;
      });

      if (country == null) return;

      final cities = await _referenceService.fetchCities(country.id);
      if (!mounted) return;

      final city = _findByName(cities, address?.cityName);
      setState(() {
        _cities = cities;
        _city = city;
      });

      if (city == null) return;

      final districts = await _referenceService.fetchDistricts(city.id);
      if (!mounted) return;
      setState(() {
        _districts = districts;
        _district = _findByName(districts, address?.districtName);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static ReferenceLocation? _findByName(
    List<ReferenceLocation> options,
    String? name,
  ) {
    if (name == null || name.isEmpty) return null;

    for (final option in options) {
      if (option.name == name) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Adres'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _canSave ? _save : null,
        title: 'Kaydet',
        isLoading: _isSaving,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _form(),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) ...[
            _errorStrip(_errorMessage!),
            const SizedBox(height: AppSizes.spaceMedium),
          ],
          _picker(
            label: 'Ülke',
            value: _country?.name,
            options: _countries,
            onSelected: _selectCountry,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _picker(
            label: 'İl',
            value: _city?.name,
            options: _cities,
            onSelected: _selectCity,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _picker(
            label: 'İlçe',
            value: _district?.name,
            options: _districts,
            onSelected: (district) => setState(() => _district = district),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: 'Açık adres',
            controller: _addressLine,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: 'Posta kodu',
            controller: _postalCode,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _locationField(),
          const SizedBox(height: AppSizes.navBarClearance),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          OutlinedButton(
            onPressed: _loadReferences,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }

  /// Açılır seçici. Liste boşken kapalı duruyor — önceki kademe seçilmeden
  /// bu kademenin içeriği bilinmiyor.
  Widget _picker({
    required String label,
    required String? value,
    required List<ReferenceLocation> options,
    required ValueChanged<ReferenceLocation> onSelected,
  }) {
    final isEnabled = options.isNotEmpty;

    return InkWell(
      onTap: isEnabled ? () => _showOptions(label, options, onSelected) : null,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const Spacer(),
            Expanded(
              child: Text(
                value ?? 'Seç',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: value == null
                      ? context.textTertiary
                      : context.textPrimary,
                  fontWeight: value == null ? null : FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary),
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
    final picked = await showModalBottomSheet<ReferenceLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: sheetContext.backgroundColor,
          borderRadius: AppRadius.sheetTop,
        ),
        padding: AppPadding.sheet,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: sheetContext.textTheme.titleLarge),
            const SizedBox(height: AppSizes.spaceMedium),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, index) => ListTile(
                  title: Text(options[index].name),
                  onTap: () => Navigator.pop(sheetContext, options[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (picked != null) onSelected(picked);
  }

  /// Ülke değişince il ve ilçe geçersiz oluyor; ikisi de sıfırlanıyor.
  Future<void> _selectCountry(ReferenceLocation country) async {
    setState(() {
      _country = country;
      _city = null;
      _district = null;
      _cities = const [];
      _districts = const [];
    });

    try {
      final cities = await _referenceService.fetchCities(country.id);
      if (mounted) setState(() => _cities = cities);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    }
  }

  Future<void> _selectCity(ReferenceLocation city) async {
    setState(() {
      _city = city;
      _district = null;
      _districts = const [];
    });

    try {
      final districts = await _referenceService.fetchDistricts(city.id);
      if (mounted) setState(() => _districts = districts);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    }
  }

  /// Koordinat alanı.
  ///
  /// Sunucu enlem ve boylamı zorunlu tutuyor; adres metninden koordinat
  /// üreten bir uç yok, o yüzden kullanıcı haritadan seçiyor. İşveren
  /// tarafındaki harita seçici burada da kullanılıyor.
  Widget _locationField() {
    final location = _location;

    return InkWell(
      onTap: _pickLocation,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(
            color: location == null
                ? context.accentColor
                : context.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: context.accentColor),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: Text(
                location == null
                    ? 'Haritadan konum seç'
                    : 'Konum seçildi · '
                          '${location.latitude.toStringAsFixed(_coordinateDigits)}, '
                          '${location.longitude.toStringAsFixed(_coordinateDigits)}',
                style: context.textTheme.bodyMedium,
              ),
            ),
            Icon(Icons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  /// Koordinatın gösterilen ondalık basamağı; sokak hassasiyeti için yeterli.
  static const int _coordinateDigits = 4;

  Future<void> _pickLocation() async {
    final picked = await context.push<LatLng>(
      '/pick-location',
      extra: _location,
    );
    if (picked == null || !mounted) return;

    setState(() => _location = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await _userService.updateAddress(
        countryCode: _country!.code ?? '',
        cityName: _city!.name,
        districtName: _district?.name,
        addressLine: _addressLine.text.trim(),
        postalCode: _postalCode.text.trim().isEmpty
            ? null
            : _postalCode.text.trim(),
        latitude: _location!.latitude,
        longitude: _location!.longitude,
      );

      if (!mounted) return;
      // Başvuru kapısı `/users/me`'deki adrese bakıyor; tazelenmeden
      // dönülürse kullanıcı hâlâ "adres eksik" uyarısını görür.
      await context.read<UserProvider>().load(silent: true);

      if (!mounted) return;
      AppToast.success(context, 'Adresin kaydedildi');
      context.pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
