import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// İlanın koordinatını haritadan seçtiren ekran.
///
/// Adres araması bir başlangıç noktası verebilir; kullanıcı son konumu bu
/// ekranda açıkça onaylar.
///
/// Pin sürüklenmiyor: harita ekranın ortasındaki sabit pinin altında
/// kayıyor, onay anında kameranın merkezi alınıyor. Sürüklenebilir marker'a
/// göre hem daha az kod hem parmağın altında kalmayan bir hedef.
///
/// `context.pop` ile seçilen [LatLng] geri döndürülüyor; vazgeçilirse `null`.
class BLocationPickerPage extends StatefulWidget {
  const BLocationPickerPage({super.key, this.initialLocation});

  /// Daha önce seçilmiş konum; ekran oraya odaklanarak açılıyor.
  final LatLng? initialLocation;

  @override
  State<BLocationPickerPage> createState() => _BLocationPickerPageState();
}

class _BLocationPickerPageState extends State<BLocationPickerPage> {
  static const LatLng _defaultTarget = LatLng(41.008238, 28.978359);
  static final LatLngBounds _serviceBounds = LatLngBounds(
    southwest: LatLng(40.80, 28.55),
    northeast: LatLng(41.35, 29.50),
  );

  /// Şehir ölçeğinde bir başlangıç; pin bırakmak için sokak seviyesine
  /// yakınlaşmak kullanıcıya bırakılıyor.
  static const double _initialZoom = 15;

  /// Sabit pinin ucu haritanın tam merkezine denk gelsin diye ikon kendi
  /// boyunun yarısı kadar yukarı kaydırılıyor.
  static const double _pinSize = 48;

  late LatLng _target = widget.initialLocation ?? _defaultTarget;
  GoogleMapController? _mapController;
  bool _locating = false;
  bool _locationGranted = false;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: 'Konum Seç'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: () => context.pop(_target),
        title: 'Bu Konumu Kullan',
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _target,
              zoom: _initialZoom,
            ),
            zoomControlsEnabled: false,
            myLocationEnabled: _locationGranted,
            myLocationButtonEnabled: false,
            cameraTargetBounds: CameraTargetBounds(_serviceBounds),
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (position) => _target = position.target,
            // Yalnızca kamera durduğunda kuruluyor: her karede setState
            // çağırmak haritayı takıyor.
            onCameraIdle: () => setState(() {}),
          ),
          _centerPin(),
          Positioned(
            top: AppSizes.space,
            left: AppSizes.space,
            right: AppSizes.space,
            child: _hintCard(),
          ),
          Positioned(
            right: AppSizes.space,
            bottom: AppSizes.space,
            child: FloatingActionButton.small(
              heroTag: 'address-current-location',
              onPressed: _locating ? null : _useCurrentLocation,
              backgroundColor: AppColors.onAccent,
              foregroundColor: AppColors.primaryColor,
              child: _locating
                  ? const SizedBox.square(
                      dimension: AppSizes.iconMedium,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Cihaz konum servisi kapalı. Pini elle seçebilirsiniz.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationMessage('Konum izni olmadan da pini elle seçebilirsiniz.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final target = LatLng(position.latitude, position.longitude);
      if (!_insideServiceArea(target)) {
        _showLocationMessage(
          'Koala şu anda yalnızca İstanbul içinde hizmet veriyor.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _locationGranted = true;
        _target = target;
      });
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 17),
      );
    } catch (_) {
      _showLocationMessage('Konum alınamadı. Pini elle seçebilirsiniz.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  bool _insideServiceArea(LatLng point) {
    return point.latitude >= _serviceBounds.southwest.latitude &&
        point.latitude <= _serviceBounds.northeast.latitude &&
        point.longitude >= _serviceBounds.southwest.longitude &&
        point.longitude <= _serviceBounds.northeast.longitude;
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Haritanın merkezindeki sabit pin.
  Widget _centerPin() {
    return IgnorePointer(
      child: Padding(
        // Pinin ucu merkezde dursun diye ikonu yarım boy yukarı al.
        padding: const EdgeInsets.only(bottom: _pinSize),
        child: AppIcon(
          AppIcons.location,
          size: _pinSize,
          color: AppColors.primaryColor,
          filled: true,
        ),
      ),
    );
  }

  /// Ne yapılacağını anlatan ve seçili koordinatı gösteren kutu.
  ///
  /// Harita iki temada da açık çizdiği için kutunun zemini ve yazısı temadan
  /// bağımsız sabit kalıyor.
  Widget _hintCard() {
    return Container(
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: AppColors.onAccent,
        borderRadius: AppRadius.innerCircular,
        boxShadow: [
          BoxShadow(
            color: AppColors.barShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Haritayı kaydırarak adresi ortadaki pine getirin',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.onLightSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            '${_target.latitude.toStringAsFixed(5)}, '
            '${_target.longitude.toStringAsFixed(5)}',
            style: context.textTheme.labelMedium?.copyWith(
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
