import 'package:material_ui/material_ui.dart';
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

/// Kullanıcının adresi: harita ekranının `PUT /users/me/address`'e bağlı hâli.
/// Çalışan başvuru kapısından, işveren ayarlardan ve ödeme kapısından geliyor.
/// Kayıt başarılıysa `UserProvider` tazelenir ve ekran kapanır.
class AddressPage extends StatelessWidget {
  const AddressPage({
    super.key,
    this.user,
    this.userService,
    this.addressSearchGateway,
    this.referenceService,
    this.locationSource,
  });

  /// Verilmezse `UserProvider`; o da yoksa harita boş açılır.
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
