import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/pending_verification.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
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

  /// Yetkinlik ve ilgi alanı kutularının yüksekliği; tanıtım yazısından
  /// kısa metinler bekleniyor.
  static const double _multilineHeight = 90;

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _occupationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _locationController;
  late TextEditingController _ibanController;
  late TextEditingController _aboutController;
  late TextEditingController _qualificationsController;
  late TextEditingController _interestsController;

  @override
  void initState() {
    super.initState();
    final user = widget.user;

    _firstNameController = TextEditingController(text: user.firstName);
    _lastNameController = TextEditingController(text: user.lastName);
    _occupationController = TextEditingController(text: user.jobTitle ?? '');
    _phoneController = TextEditingController(text: user.phoneNumber ?? '');
    _emailController = TextEditingController(text: user.email);
    _locationController = TextEditingController(
      text: user.address?.shortLabel ?? '',
    );
    // IBAN sunucudan maskeli geliyor; alan boş açılıyor ve maske ipucu
    // olarak gösteriliyor. Maskeyi alana yazsaydık kullanıcı kaydettiğinde
    // maskenin kendisi IBAN diye gönderilirdi.
    _ibanController = TextEditingController();
    _aboutController = TextEditingController(text: user.about ?? '');
    _qualificationsController = TextEditingController(
      text: user.qualifications ?? '',
    );
    _interestsController = TextEditingController(text: user.interests ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _occupationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _ibanController.dispose();
    _aboutController.dispose();
    _qualificationsController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  /// Kimliği doğrulanmış kullanıcı ad ve soyadını değiştiremiyor; backend
  /// isteği reddettiği için alanlar en baştan kapalı açılıyor.
  bool get _canEditName => !widget.user.identityVerified;

  Future<void> _pickProfilePicture() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (image == null || !mounted) return;

    final provider = context.read<UserProvider>();
    final uploaded = await provider.uploadProfilePicture(image.path);
    if (!mounted) return;
    if (uploaded) {
      AppToast.success(context, 'Profil fotoğrafın güncellendi.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Profil fotoğrafı yüklenemedi.',
      );
    }
  }

  Future<void> _save() async {
    final provider = context.read<UserProvider>();
    // Karşılaştırma tabanı sağlayıcıdaki güncel kullanıcı: doğrulama
    // tamamlandıktan sonra alanlar tazeleniyor ve `widget.user` (ekrana
    // girilirken alınan görüntü) bayatlıyor. Bayat tabanla ikinci kaydetme,
    // hiçbir şey değişmemişken e-postayı yeniden gönderir ve gereksiz bir
    // doğrulama daha başlatırdı.
    final user = provider.user ?? widget.user;

    // PATCH kısmi: değişmeyen alan gövdeye hiç konmuyor. Aksi hâlde kimliği
    // doğrulanmış kullanıcı hiçbir şeyi değiştirmese bile ad alanını
    // gönderdiği için hata alırdı.
    final firstName = _changed(_firstNameController.text, user.firstName);
    final lastName = _changed(_lastNameController.text, user.lastName);
    final about = _changed(_aboutController.text, user.about);
    final phoneNumber = _changed(_phoneController.text, user.phoneNumber);
    final jobTitle = _changed(_occupationController.text, user.jobTitle);
    final qualifications = _changed(
      _qualificationsController.text,
      user.qualifications,
    );
    final interests = _changed(_interestsController.text, user.interests);
    // E-posta ve telefon değişikliği hemen yazılmıyor: sunucu yeni değere kod
    // gönderip bekleyen doğrulamayı döndürüyor.
    final email = _changed(_emailController.text, user.email);

    // IBAN alanı boş bırakıldıysa hiç gönderilmiyor: kayıtlı IBAN
    // maskelendiği için "değişti mi" karşılaştırması yapılamıyor, boş metin
    // göndermek de kayıtlıyı bozardı.
    final iban = _ibanController.text.trim();

    final pending = await provider.updateProfile(
      firstName: _canEditName ? firstName : null,
      lastName: _canEditName ? lastName : null,
      about: about,
      jobTitle: jobTitle,
      qualifications: qualifications,
      interests: interests,
      phoneNumber: phoneNumber,
      email: email,
      iban: iban.isEmpty ? null : iban,
    );

    if (!mounted) return;

    if (pending == null) {
      // Backend başka hesapta kayıtlı e-postayı reddediyor. Durum koduna
      // bakılmıyor, bakılmamalı da: `UsersController`'ın `@ApiResponse`'u bu
      // durum için `409` belgeliyor ama `UserManager` `ValidationException`
      // fırlattığı için gerçekte `400` dönüyor. Mesaj sunucudan Türkçe
      // geldiği için olduğu gibi gösteriliyor.
      AppToast.error(
        context,
        provider.errorMessage ?? "Profil güncellenemedi.",
      );
      return;
    }

    if (pending.isEmpty) {
      AppToast.success(context, "Profilin güncellendi.");
      context.pop();
      return;
    }

    await _collectVerifications(pending);
  }

  /// Bekleyen doğrulamaları sırayla kod ekranına götürür.
  ///
  /// Tek bir `PATCH` hem telefonu hem e-postayı değiştirebiliyor, o yüzden
  /// liste birden fazla olabilir. Biri onaylanınca sıradaki açılıyor;
  /// kullanıcı vazgeçerse ya da kayıt geçersizse sıra orada kesiliyor —
  /// kalanları zorlamak, kullanıcının bıraktığı ekranı geri açmak olurdu.
  ///
  /// Hepsi bitince hesap ekranında kalınıyor ve alanlar tazelenen kullanıcıyla
  /// güncelleniyor; yeni değerin yazıldığı böylece görülebiliyor.
  Future<void> _collectVerifications(List<PendingVerification> pending) async {
    for (final verification in pending) {
      final verified = await context.push<bool>(
        '/verification',
        extra: verification,
      );
      if (!mounted) return;
      if (verified != true) break;
    }

    if (!mounted) return;
    _syncVerifiedFields();
  }

  /// Doğrulama sonrası sunucudaki güncel değerleri alanlara yazar.
  ///
  /// Kontrolcüler `initState`'te bir kez dolduruluyor; tazelenen kullanıcıyı
  /// buraya yansıtmazsak ekran hâlâ eski e-postayı gösterirdi.
  void _syncVerifiedFields() {
    final refreshed = context.read<UserProvider>().user;
    if (refreshed == null) return;

    setState(() {
      _emailController.text = refreshed.email;
      _phoneController.text = refreshed.phoneNumber ?? '';
    });
  }

  /// Yeni değer eskisinden farklıysa onu, aynıysa `null` döner.
  static String? _changed(String value, String? current) {
    final trimmed = value.trim();
    return trimmed == (current ?? '') ? null : trimmed;
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
              MyTextfield(
                labelText: "E-posta",
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              _hint(
                "Telefonunu ya da e-postanı değiştirirsen yeni değere bir "
                "kod gönderiyoruz; kodu girene kadar eskisi geçerli kalıyor.",
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              // Adres kendi ekranında düzenleniyor: uç toptan yazıyor ve
              // ülke/il/ilçe seçicisiyle koordinat istiyor.
              _addressRow(),
              const SizedBox(height: AppSizes.spaceMedium),
              _identityRow(),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "IBAN",
                controller: _ibanController,
                keyboardType: TextInputType.text,
              ),
              _hint(
                widget.user.maskedIban == null
                    ? "İşe başvurabilmen için ücretini alacağın IBAN'ı "
                          "eklemen gerekiyor."
                    : "Kayıtlı: ${widget.user.maskedIban}. Değiştirmek "
                          "istemiyorsan boş bırak.",
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              _aboutTextField(),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Yetkinlikler",
                controller: _qualificationsController,
                expands: true,
                height: _multilineHeight,
              ),
              _hint(
                "Yaptığın işte öne çıkan tarafların. İşveren başvurunda "
                "bunları görüyor.",
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "İlgi alanları",
                controller: _interestsController,
                expands: true,
                height: _multilineHeight,
              ),
              const SizedBox(height: AppSizes.sectionSpace),
            ],
          ),
        ),
      ),
    );
  }

  /// Adres satırı: özet ve düzenleme ekranına geçiş.
  Widget _addressRow() {
    final label = _locationController.text;

    return _linkRow(
      label: "Adres",
      value: label.isEmpty ? "Eklenmedi" : label,
      isMissing: label.isEmpty,
      onTap: () async {
        await context.push('/address', extra: widget.user);
        if (mounted) context.pop();
      },
    );
  }

  /// Kimlik doğrulama satırı. Doğrulanmışsa yalnızca durumu gösteriyor.
  Widget _identityRow() {
    if (widget.user.identityVerified) {
      return _linkRow(
        label: "Kimlik",
        value: "Doğrulandı",
        isMissing: false,
        onTap: null,
      );
    }

    return _linkRow(
      label: "Kimlik",
      value: "Doğrulanmadı",
      isMissing: true,
      onTap: () async {
        await context.push('/identity-verification', extra: widget.user);
        if (mounted) context.pop();
      },
    );
  }

  /// Başka bir ekrana götüren satır. Eksik bilgi vurgulu duruyor: üçü de
  /// başvurunun ön koşulu.
  Widget _linkRow({
    required String label,
    required String value,
    required bool isMissing,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(
            color: isMissing ? AppColors.warning : context.dividerColor,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const Spacer(),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isMissing ? AppColors.warning : context.textPrimary,
                ),
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: context.textTertiary),
          ],
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

  Widget _avatar() {
    final visibleUser = context.watch<UserProvider>().user ?? widget.user;
    return GestureDetector(
      key: const ValueKey('profile-picture-picker'),
      onTap: _pickProfilePicture,
      child: Stack(
        children: [
          ProfileAvatar(
            imageUrl: visibleUser.profilePictureUrl,
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
              child: AppIcon(
                AppIcons.camera,
                color: context.onAccentColor,
                size: AppSizes.iconSmall,
              ),
            ),
          ),
        ],
      ),
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
