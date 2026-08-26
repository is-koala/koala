import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/profile/models/user.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';

class AccountInfoPage extends StatefulWidget {
  final User user;

  const AccountInfoPage({super.key, required this.user});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  /// Profil fotoğrafının kenar uzunluğu.
  static const double _avatarSize = 100;

  /// "Hakkımda" alanının yüksekliği: yaklaşık dört satır.
  static const double _aboutHeight = 120;

  late TextEditingController _fullNameController;
  late TextEditingController _jobTitleController;
  late TextEditingController _locationController;
  late TextEditingController _aboutController;
  late TextEditingController _cvFileNameController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _jobTitleController = TextEditingController(text: widget.user.jobTitle);
    _locationController = TextEditingController(text: widget.user.location);
    _aboutController = TextEditingController(text: widget.user.about);
    _cvFileNameController = TextEditingController(text: widget.user.cvFileName);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _jobTitleController.dispose();
    _locationController.dispose();
    _aboutController.dispose();
    _cvFileNameController.dispose();
    super.dispose();
  }

  void _save() {
    final updatedUser = widget.user.copyWith(
      fullName: _fullNameController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      location: _locationController.text.trim(),
      about: _aboutController.text.trim(),
      cvFileName: _cvFileNameController.text.trim(),
    );
    context.pop(updatedUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: "Hesabı Düzenle"),
      bottomNavigationBar: ButtonNavbar(onPressed: _save, title: "Kaydet"),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _avatar()),
              const SizedBox(height: AppSizes.sectionSpace),
              MyTextfield(
                labelText: "Ad Soyad",
                controller: _fullNameController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Meslek", controller: _jobTitleController),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Konum", controller: _locationController),
              const SizedBox(height: AppSizes.spaceMedium),
              _aboutTextField(),
              // SizedBox(height: 16),
              // MyTextfield(
              //   labelText: "CV Dosya Adı",
              //   controller: _cvFileNameController,
              // ),
              const SizedBox(height: AppSizes.sectionSpace),
            ],
          ),
        ),
      ),
    );
  }

  /// Profil fotoğrafı ve üstündeki değiştirme rozeti.
  Widget _avatar() {
    return Stack(
      children: [
        Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            borderRadius: AppRadius.secondaryCircular,
            image: DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage(widget.user.profileImage),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spaceTiny),
            decoration: BoxDecoration(
              color: context.accentColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.camera_alt,
              color: context.onAccentColor,
              size: AppSizes.iconSmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _aboutTextField() {
    return MyTextfield(
      labelText: "Hakkımda",
      controller: _aboutController,
      height: _aboutHeight,
      expands: true,
      // Tek satırlık alanların tam yuvarlak köşesi bu yükseklikte metni
      // sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }
}
