import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/presentation/company_identity_gate.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirmed_address_field.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

part 'company_informations_pagemodel.dart';

class CompanyInformationsPage extends StatefulWidget {
  const CompanyInformationsPage({
    super.key,
    this.service,
    this.initialAddress,
    this.onSaved,
  });

  final BCompanyService? service;

  /// Formun açılışta taşıdığı adres; testler harita ekranını atlamak için
  /// verir, üretimde işveren adresi haritadan seçer.
  final ConfirmedAddress? initialAddress;
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
    return PopScope<Object?>(
      canPop: canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: AppIcon(AppIcons.arrowLeft, color: context.textPrimary),
            onPressed: goBack,
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
          ConfirmedAddressField(
            value: address,
            label: 'Şirket adresi *',
            onTap: pickAddress,
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
