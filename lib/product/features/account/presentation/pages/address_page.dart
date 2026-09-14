import 'package:flutter/material.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/services/address_search_service.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';
import 'package:provider/provider.dart';

/// Kullanıcının kendi adresi: harita-öncelikli ekranın
/// `PUT /users/me/address` ile bağlanmış hâli.
///
/// Adres hesaba ait, tarafına değil: çalışan başvuru kapısından, işveren
/// ayarlardaki *Adresim* satırından ve ödeme kapısından aynı ekrana geliyor.
/// Bireysel işverenin ödemesi bu adres olmadan başlamıyor
/// (`JOB_ASSIGNMENT_ADDRESS_NOT_PROVIDED_FOR_EMPLOYER`); önceden işveren
/// tarafında bu ekranın hiç yolu yoktu.
///
/// Kayıt başarılıysa `UserProvider` tazelenir ve ekran kapanır; açan ekran
/// (hesap bilgileri, başvuru kapısı, işveren profili) tazelenmiş kullanıcıyı
/// zaten izliyor.
class AddressPage extends StatelessWidget {
  const AddressPage({
    super.key,
    this.user,
    this.userService,
    this.addressSearchGateway,
    this.referenceService,
    this.locationSource,
  });

  /// Ekranın açılacağı kullanıcı. Verilmezse `UserProvider`'daki kullanıcı
  /// okunuyor; o da yoksa harita boş adresle açılıyor — kullanıcı adresini
  /// yine girebiliyor, yalnız önceden dolu alan olmuyor.
  final CurrentUser? user;

  final UserService? userService;
  final AddressSearchGateway? addressSearchGateway;
  final ReferenceLocationService? referenceService;
  final DeviceLocationSource? locationSource;

  @override
  Widget build(BuildContext context) {
    final current = user ?? context.read<UserProvider>().user;

    return MapFirstAddressPage(
      title: 'Adresim',
      initialAddress: ConfirmedAddress.fromCanonical(current?.address),
      addressSearchGateway: addressSearchGateway,
      referenceService: referenceService,
      locationSource: locationSource,
      onSave: (address) => _save(context, address),
    );
  }

  Future<void> _save(BuildContext context, ConfirmedAddress address) async {
    final service = userService ?? UserService();
    await service.updateAddress(address.toWrite());
    if (!context.mounted) return;
    await context.read<UserProvider>().load(silent: true);
    if (!context.mounted) return;
    AppToast.success(context, 'Adresiniz kaydedildi');
  }
}
