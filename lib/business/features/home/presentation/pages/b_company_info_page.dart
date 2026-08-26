import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/services/fake_business_company.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class BCompanyInfoPage extends StatefulWidget {
  const BCompanyInfoPage({super.key});

  @override
  State<BCompanyInfoPage> createState() => _BCompanyInfoPageState();
}

class _BCompanyInfoPageState extends State<BCompanyInfoPage> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _websiteController;
  late TextEditingController _descriptionController;
  late TextEditingController _taxNumberController;
  late TextEditingController _streetController;
  late TextEditingController _districtController;
  late TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    final company = FakeBusinessCompany.instance;
    _nameController = TextEditingController(text: company.name);
    _emailController = TextEditingController(text: company.email);
    _phoneController = TextEditingController(text: company.phoneNumber ?? '');
    _websiteController = TextEditingController(text: company.website ?? '');
    _descriptionController = TextEditingController(
      text: company.description ?? '',
    );
    _taxNumberController = TextEditingController(text: company.taxNumber ?? '');
    _streetController = TextEditingController(
      text: company.address?.street ?? '',
    );
    _districtController = TextEditingController(
      text: company.address?.district ?? '',
    );
    _cityController = TextEditingController(text: company.address?.city ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _descriptionController.dispose();
    _taxNumberController.dispose();
    _streetController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _save() {
    final old = FakeBusinessCompany.instance;

    final updated = Company(
      id: old.id,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      logo: old.logo,
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      address: old.address,
      taxNumber: _taxNumberController.text.trim().isEmpty
          ? null
          : _taxNumberController.text.trim(),
      type: old.type,
      isApproved: old.isApproved,
    );

    context.pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Firma Bilgileri"),
      bottomNavigationBar: ButtonNavbar(onPressed: _save, title: "Kaydet"),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel("Firma Bilgileri"),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Firma Adı", controller: _nameController),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "E-posta",
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Telefon",
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Website",
                controller: _websiteController,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Vergi Numarası",
                controller: _taxNumberController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              _sectionLabel("Hakkımızda"),
              const SizedBox(height: AppSizes.space),
              _descriptionTextField(),
              const SizedBox(height: AppSizes.spaceLarge),
              _sectionLabel("Adres Bilgileri"),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Sokak / Cadde",
                controller: _streetController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "İlçe", controller: _districtController),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Şehir", controller: _cityController),
              const SizedBox(height: AppSizes.sectionSpace),
            ],
          ),
        ),
      ),
    );
  }

  /// "Hakkımızda" alanının yüksekliği: yaklaşık dört satır.
  static const double _descriptionHeight = 120;

  Widget _sectionLabel(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  Widget _descriptionTextField() {
    return MyTextfield(
      labelText: "Açıklama",
      controller: _descriptionController,
      height: _descriptionHeight,
      expands: true,
      // Tek satırlık alanların tam yuvarlak köşesi bu yükseklikte metni
      // sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }
}
