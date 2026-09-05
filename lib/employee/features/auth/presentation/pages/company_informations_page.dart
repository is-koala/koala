import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

part 'company_informations_pagemodel.dart';

class CompanyInformationsPage extends StatefulWidget {
  const CompanyInformationsPage({
    super.key,
    this.service,
    this.initialLocation,
    this.onSaved,
  });

  final BCompanyService? service;
  final LatLng? initialLocation;
  final VoidCallback? onSaved;

  @override
  State<CompanyInformationsPage> createState() =>
      _CompanyInformationsPageState();
}

class _CompanyInformationsPageState extends CompanyInformationsPagemodel {
  /// Açıklama alanının yüksekliği; yanındaki logo kutusuyla aynı boyda
  /// dursun diye satır yüksekliğini bu belirliyor.
  static const double _descriptionHeight = 100;

  /// Logo seçim kutusunun ölçüsü.
  static const double _logoBoxWidth = 80;
  static const double _avatarRadius = 40;
  static const double _editBadgeSize = 30;
  static const double _editBadgeBorder = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppIcons.arrowLeft, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: AppPadding.authContent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _formSection(),
                MyButton(
                  key: const ValueKey('company-save'),
                  onPressed: saveCompanyInformation,
                  title: "KAYDET",
                  isLoading: isSaving,
                ),
                const SizedBox(height: AppSizes.spaceLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formSection() {
    return Padding(
      padding: AppPadding.horizontalSmall,
      child: Column(
        children: [
          Text(
            "Şirket Bilgilerini Giriniz",
            style: context.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.spaceXLarge),
          MyTextfield(
            labelText: "Firma Adı*",
            controller: companyNameController,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Firma Adresi*",
            controller: companyAddressController,
            keyboardType: TextInputType.streetAddress,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "İlçe*",
            controller: districtController,
            keyboardType: TextInputType.streetAddress,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Vergi Numarası*",
            controller: taxNumberController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _companyTypePicker(),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Şirket Numarası*",
            controller: companyPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Şirket E-posta*",
            controller: companyEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Website",
            controller: websiteController,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _locationField(),
          const SizedBox(height: AppSizes.spaceMedium),
          _descriptionRow(),
          const SizedBox(height: AppSizes.spaceXLarge),
        ],
      ),
    );
  }

  Widget _companyTypePicker() {
    return DropdownButtonFormField<CompanyType>(
      initialValue: companyType,
      decoration: const InputDecoration(
        labelText: 'Şirket Türü*',
        border: OutlineInputBorder(),
      ),
      items: CompanyType.values
          .map(
            (type) =>
                DropdownMenuItem(value: type, child: Text(type.displayName)),
          )
          .toList(),
      onChanged: (type) {
        if (type != null) setState(() => companyType = type);
      },
    );
  }

  Widget _locationField() {
    final location = selectedLocation;
    return ListTile(
      key: const ValueKey('company-location'),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.dividerColor),
        borderRadius: AppRadius.smallCircular,
      ),
      title: const Text('Şirket Konumu*'),
      subtitle: Text(
        location == null
            ? 'Haritadan konum seç'
            : '${location.latitude.toStringAsFixed(5)}, '
                  '${location.longitude.toStringAsFixed(5)}',
      ),
      trailing: const AppIcon(AppIcons.location),
      onTap: pickLocation,
    );
  }

  Widget _descriptionRow() {
    return Row(
      children: [
        Expanded(
          child: MyTextfield(
            labelText: "Açıklama",
            controller: descriptionController,
            height: _descriptionHeight,
            expands: true,
          ),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
        _logoPicker(),
      ],
    );
  }

  Widget _logoPicker() {
    final avatar = AppColors.avatarColorFor(companyNameController.text.trim());

    return GestureDetector(
      onTap: pickLogo,
      child: SizedBox(
        width: _logoBoxWidth,
        height: _descriptionHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: _avatarRadius,
              backgroundColor: avatar.background,
              backgroundImage: logoPath == null
                  ? null
                  : FileImage(File(logoPath!)),
              child: logoPath == null
                  ? Text(
                      companyInitials,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: avatar.foreground,
                      ),
                    )
                  : null,
            ),
            // Düzenle rozeti köşede
            Positioned(
              bottom: AppSizes.spaceTiny,
              right: AppSizes.spaceTiny,
              child: Container(
                width: _editBadgeSize,
                height: _editBadgeSize,
                decoration: BoxDecoration(
                  color: context.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.backgroundColor,
                    width: _editBadgeBorder,
                  ),
                ),
                child: AppIcon(
                  AppIcons.edit,
                  size: AppSizes.iconSmall,
                  color: context.onAccentColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
