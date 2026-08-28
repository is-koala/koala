import 'package:flutter/material.dart';
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
/// Backend ilan açarken `latitude`/`longitude` alanlarını zorunlu tutuyor ve
/// serbest metin adresi koordinata çevirmiyor; işverenin pini kendisi
/// bırakması gerekiyor. Aksi hâlde bütün ilanlar aynı noktaya düşer.
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
  /// Hiç konum seçilmemişse haritanın açıldığı yer: Ankara. Keşfet haritası da
  /// aynı noktadan başlıyor.
  static const LatLng _defaultTarget = LatLng(39.925533, 32.866287);

  /// Şehir ölçeğinde bir başlangıç; pin bırakmak için sokak seviyesine
  /// yakınlaşmak kullanıcıya bırakılıyor.
  static const double _initialZoom = 15;

  /// Sabit pinin ucu haritanın tam merkezine denk gelsin diye ikon kendi
  /// boyunun yarısı kadar yukarı kaydırılıyor.
  static const double _pinSize = 48;

  late LatLng _target = widget.initialLocation ?? _defaultTarget;

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
            myLocationButtonEnabled: false,
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
        ],
      ),
    );
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
            'Haritayı kaydırarak ilanın konumunu ortadaki pine getirin',
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
