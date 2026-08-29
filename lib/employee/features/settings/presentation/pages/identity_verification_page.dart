import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

/// Kimlik doğrulama formu.
///
/// İlana başvurabilmenin ilk şartı: sunucu doğrulanmamış kullanıcının
/// başvurusunu `APPLICANT_IDENTITY_NOT_VERIFIED` ile reddediyor. Bilgiler
/// NVİ'ye soruluyor, o yüzden kimlik kartındakiyle birebir aynı olmalı.
///
/// Doğrulama başarılı olduğunda ad ve soyad **kilitleniyor** — hesap bilgileri
/// ekranı da o noktadan sonra ikisini düzenletmiyor.
class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key, required this.user});

  final CurrentUser user;

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  final UserService _userService = UserService();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _tcIdentity;
  late final TextEditingController _tcDocument;

  DateTime? _birthDate;
  bool _isSubmitting = false;

  /// TC kimlik numarası tam 11 hane.
  static const int _tcIdentityLength = 11;

  /// Doğum tarihi seçicinin gidebileceği en eski yıl.
  static const int _earliestYear = 1920;

  /// Çalışma yaşı alt sınırı; seçici bundan yenisini göstermiyor.
  static const int _minimumAge = 15;

  @override
  void initState() {
    super.initState();
    // Kayıtta girilen ad ve soyad çoğu kullanıcıda kimliktekiyle aynı;
    // form boş açılırsa gereksiz yere yeniden yazdırmış oluruz.
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _tcIdentity = TextEditingController();
    _tcDocument = TextEditingController();
    _birthDate = widget.user.birthDate;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _tcIdentity.dispose();
    _tcDocument.dispose();
    super.dispose();
  }

  /// Gönderilebilir mi. Sunucunun deseni ayrıca doğruluyor; buradaki kontrol
  /// kullanıcıyı boşuna bir gidiş dönüşten kurtarıyor.
  bool get _canSubmit =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _tcIdentity.text.trim().length == _tcIdentityLength &&
      _tcDocument.text.trim().isNotEmpty &&
      _birthDate != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Kimlik Doğrulama'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _canSubmit ? _submit : null,
        title: 'Doğrula',
        isLoading: _isSubmitting,
      ),
      body: SingleChildScrollView(
        padding: AppPadding.primaryAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _intro(),
            const SizedBox(height: AppSizes.spaceLarge),
            MyTextfield(
              labelText: 'Ad',
              controller: _firstName,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: 'Soyad',
              controller: _lastName,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: 'TC Kimlik No',
              controller: _tcIdentity,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_tcIdentityLength),
              ],
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyTextfield(
              labelText: 'Seri No',
              controller: _tcDocument,
              onChanged: (_) => setState(() {}),
            ),
            _hint('Kimlik kartının ön yüzündeki seri numarası.'),
            const SizedBox(height: AppSizes.spaceMedium),
            _birthDateField(),
            const SizedBox(height: AppSizes.navBarClearance),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(
        'İşe başvurabilmen ve ücretini alabilmen için kimliğini bir kez '
        'doğrulaman gerekiyor. Bilgiler kimlik kartındakiyle birebir aynı '
        'olmalı; doğrulandıktan sonra adın ve soyadın değiştirilemez.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.textSecondary,
          height: _lineHeight,
        ),
      ),
    );
  }

  /// Bilgilendirme metinlerinin satır aralığı.
  static const double _lineHeight = 1.4;

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

  Widget _birthDateField() {
    final birthDate = _birthDate;

    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Text(
              'Doğum tarihi',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              birthDate == null ? 'Seç' : birthDate.asShortDate,
              style: context.textTheme.bodyMedium?.copyWith(
                color: birthDate == null ? context.textTertiary : null,
                fontWeight: birthDate == null ? null : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final latest = DateTime(now.year - _minimumAge, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? latest,
      firstDate: DateTime(_earliestYear),
      lastDate: latest,
    );
    if (picked == null) return;

    setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      await _userService.verifyIdentity(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        birthDate: _birthDate!,
        tcIdentityNumber: _tcIdentity.text.trim(),
        tcDocumentNumber: _tcDocument.text.trim(),
      );

      if (!mounted) return;
      // `identityVerified` bayrağı `/users/me`'den okunuyor; başvuru kapısı
      // da oraya bakıyor, o yüzden kullanıcı tazelenmeden dönülmemeli.
      await context.read<UserProvider>().load(silent: true);

      if (!mounted) return;
      AppToast.success(context, 'Kimliğin doğrulandı');
      context.pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      // 400: bilgiler NVİ'de tutmadı. 502: doğrulama servisine ulaşılamadı.
      // İkisinin de mesajı sunucudan Türkçe geliyor.
      AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
