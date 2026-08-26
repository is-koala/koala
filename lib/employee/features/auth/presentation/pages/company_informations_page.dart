import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

part 'company_informations_pagemodel.dart';

class CompanyInformationsPage extends StatefulWidget {
  const CompanyInformationsPage({super.key});

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
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: context.textPrimary,
          ),
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
                MyButton(onPressed: saveCompanyInformation, title: "KAYDET"),
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
            labelText: "Vergi Numarası*",
            controller: taxNumberController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Sektör*",
            controller: sectorController,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Şirket Numarası",
            controller: companyPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: "Şirket E-posta",
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
      onTap: () {
        // TODO(backend): Logo seçme ve yükleme akışı bağlanacak.
      },
      child: SizedBox(
        width: _logoBoxWidth,
        height: _descriptionHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: _avatarRadius,
              backgroundColor: avatar.background,
              child: Text(
                companyInitials,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: avatar.foreground,
                ),
              ),
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
                child: Icon(
                  HugeIcons.strokeRoundedEdit03,
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
