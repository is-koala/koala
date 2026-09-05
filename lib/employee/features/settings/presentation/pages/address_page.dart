import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/canonical_address_form.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class AddressPage extends StatefulWidget {
  const AddressPage({super.key, required this.user});

  final CurrentUser user;

  @override
  State<AddressPage> createState() => _AddressPageState();
}

class _AddressPageState extends State<AddressPage> {
  final UserService _userService = UserService();
  late final CanonicalAddressFormController _addressController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addressController = CanonicalAddressFormController(
      initialAddress: widget.user.address,
    )..addListener(_refresh);
  }

  @override
  void dispose() {
    _addressController.removeListener(_refresh);
    _addressController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Adres'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _addressController.value == null ? _showValidation : _save,
        title: 'Kaydet',
        isLoading: _isSaving,
      ),
      body: SingleChildScrollView(
        padding: AppPadding.primaryAll,
        child: Column(
          children: [
            CanonicalAddressForm(
              controller: _addressController,
              pickPosition: _pickPosition,
            ),
            const SizedBox(height: AppSizes.navBarClearance),
          ],
        ),
      ),
    );
  }

  Future<LatLng?> _pickPosition(LatLng? initialPosition) {
    return context.push<LatLng>('/pick-location', extra: initialPosition);
  }

  void _showValidation() {
    AppToast.error(
      context,
      _addressController.validationMessage ?? 'Adres bilgilerini tamamlayın',
    );
  }

  Future<void> _save() async {
    final address = _addressController.value;
    if (address == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      await _userService.updateAddress(address);
      if (!mounted) return;
      await context.read<UserProvider>().load(silent: true);
      if (!mounted) return;
      AppToast.success(context, 'Adresin kaydedildi');
      context.pop(true);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
