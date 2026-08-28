import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

class AccountInfoPage extends StatefulWidget {
  final CurrentUser user;

  const AccountInfoPage({super.key, required this.user});

  @override
  State<AccountInfoPage> createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  /// Profil fotoğrafının kenar uzunluğu.
  static const double _avatarSize = 100;

  /// "Hakkımda" alanının yüksekliği: yaklaşık dört satır.
  static const double _aboutHeight = 120;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _occupationController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _aboutController;

  @override
  void initState() {
    super.initState();
    final user = widget.user;

    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _occupationController = TextEditingController(text: user.jobTitle ?? '');
    _phoneController = TextEditingController(text: user.phoneNumber ?? '');
    _locationController = TextEditingController(
      text: user.address?.shortLabel ?? '',
    );
    _aboutController = TextEditingController(text: user.about ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _occupationController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  /// Kimliği doğrulanmış kullanıcı ad ve soyadını değiştiremiyor; backend
  /// isteği reddettiği için alanlar en baştan kapalı açılıyor.
  bool get _canEditName => !widget.user.identityVerified;

  Future<void> _save() async {
    final user = widget.user;
    final provider = context.read<UserProvider>();

    // PATCH kısmi: değişmeyen alan gövdeye hiç konmuyor. Aksi hâlde kimliği
    // doğrulanmış kullanıcı hiçbir şeyi değiştirmese bile ad alanını
    // gönderdiği için hata alırdı.
    final firstName = _changed(_firstNameController.text, user.firstName);
    final lastName = _changed(_lastNameController.text, user.lastName);
    final about = _changed(_aboutController.text, user.about);
    final phoneNumber = _changed(_phoneController.text, user.phoneNumber);
    final jobTitle = _changed(_occupationController.text, user.jobTitle);

    final pending = await provider.updateProfile(
      firstName: _canEditName ? firstName : null,
      lastName: _canEditName ? lastName : null,
      about: about,
      jobTitle: jobTitle,
      phoneNumber: phoneNumber,
    );

    if (!mounted) return;

    if (pending == null) {
      _showMessage(provider.errorMessage ?? "Profil güncellenemedi.");
      return;
    }

    _showMessage(_successMessage(pending));
    context.pop();
  }

  /// Yeni değer eskisinden farklıysa onu, aynıysa `null` döner.
  static String? _changed(String value, String? current) {
    final trimmed = value.trim();
    return trimmed == (current ?? '') ? null : trimmed;
  }

  /// Telefon değişikliği hemen yazılmıyor; kullanıcı doğrulamayı tamamlayana
  /// kadar eski numara geçerli olduğu için mesaj buna göre kuruluyor.
  static String _successMessage(List<PendingVerification> pending) {
    if (pending.isEmpty) return "Profilin güncellendi.";

    final message = pending.first.message;
    if (message != null && message.isNotEmpty) return message;

    return "Profilin güncellendi. Doğrulama bekleyen alanlar var.";
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = context.watch<UserProvider>().isLoading;

    return Scaffold(
      appBar: MyAppbar(title: "Hesabı Düzenle"),
      bottomNavigationBar: ButtonNavbar(
        onPressed: isSaving ? null : _save,
        title: "Kaydet",
        isLoading: isSaving,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _avatar()),
              const SizedBox(height: AppSizes.sectionSpace),
              MyTextfield(
                labelText: "Ad",
                controller: _firstNameController,
                enabled: _canEditName,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Soyad",
                controller: _lastNameController,
                enabled: _canEditName,
              ),
              if (!_canEditName)
                _hint(
                  "Kimliğin doğrulandığı için ad ve soyad "
                  "değiştirilemiyor.",
                ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Meslek",
                controller: _occupationController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Telefon",
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              // TODO(backend): Konum `PUT /users/me/address` ile yazılıyor ve
              // ülke/şehir/ilçe kimliği istiyor; `/reference` uçlarından
              // beslenen bir seçici gerekiyor. O ekran gelene kadar salt
              // okunur.
              MyTextfield(
                labelText: "Konum",
                controller: _locationController,
                enabled: false,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              _aboutTextField(),
              const SizedBox(height: AppSizes.sectionSpace),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.spaceTiny,
        left: AppSizes.space,
      ),
      child: Text(
        text,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.textTertiary,
        ),
      ),
    );
  }

  /// Profil fotoğrafı ve üstündeki değiştirme rozeti.
  ///
  /// TODO(backend): `PUT /users/me/profile-picture` multipart bekliyor; görsel
  /// seçmek için henüz bir yol yok, rozet şimdilik sadece duruyor.
  Widget _avatar() {
    return Stack(
      children: [
        ProfileAvatar(
          imageUrl: widget.user.profilePictureUrl,
          size: _avatarSize,
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
