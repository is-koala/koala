import 'package:flutter/material.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/services/address_search_service.dart';
import 'package:koala/product/services/device_location_source.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

/// Şirket adresi: harita-öncelikli ekranın `PATCH /companies/{id}`
/// gövdesindeki `address` alanına bağlanmış hâli (is-koala/koala#184).
///
/// *Adresim* (`AddressPage`) ile aynı kalıp: ekran adresi kendisi kaydeder,
/// sunucu reddederse `MapFirstAddressPage` açık kalıp hatayı gösterir,
/// başarıda `BCompanyProvider` yanıttaki şirketle tazelenir ve ekran
/// kapanır; firma bilgileri sayfası sağlayıcıyı zaten izliyor.
///
/// Firma bilgileri sayfası buraya yalnızca şirket yüklüyken ve kullanıcı
/// `ADMIN` iken yol veriyor; sunucu da yetkiyi kendisi denetliyor.
class BCompanyAddressPage extends StatelessWidget {
  const BCompanyAddressPage({
    super.key,
    this.addressSearchGateway,
    this.referenceService,
    this.locationSource,
  });

  final AddressSearchGateway? addressSearchGateway;
  final ReferenceLocationService? referenceService;
  final DeviceLocationSource? locationSource;

  static const String title = 'Şirket Adresi';

  @override
  Widget build(BuildContext context) {
    final company = context.read<BCompanyProvider>().company;

    if (company == null) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: MyAppbar(title: title),
        body: const EmptyState(
          icon: AppIcons.building,
          title: 'Kayıtlı firmanız yok',
          description: 'Şirket adresi için önce firma kaydı gerekiyor.',
        ),
      );
    }

    return MapFirstAddressPage(
      title: title,
      initialAddress: ConfirmedAddress.fromCanonical(company.address),
      addressSearchGateway: addressSearchGateway,
      referenceService: referenceService,
      locationSource: locationSource,
      onSave: (address) => _save(context, address),
    );
  }

  Future<void> _save(BuildContext context, ConfirmedAddress address) async {
    await context.read<BCompanyProvider>().updateAddress(address);
    if (!context.mounted) return;
    AppToast.success(context, 'Şirket adresiniz kaydedildi');
  }
}
