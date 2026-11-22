import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';
import 'package:koala/employee/features/jobs/models/application_readiness.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_list_tile.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/settings_hint.dart';
import 'package:provider/provider.dart';

class ApplyPage extends StatefulWidget {
  final Job job;

  const ApplyPage({super.key, required this.job});

  @override
  State<ApplyPage> createState() => _ApplyPageState();
}

class _ApplyPageState extends State<ApplyPage> {
  final TextEditingController _coverLetterController = TextEditingController();
  bool _agreedToTerms = false;

  static const int _coverLetterMaxLength = 500;

  /// Ön yazı alanının yüksekliği; diğer formlardaki açıklama alanıyla aynı.
  static const double _coverLetterHeight = 120;

  /// Onay kutusunun dokunma alanı.
  static const double _checkboxSize = 24;

  /// Başarı diyaloğundaki tik dairesi.
  static const double _successCircleSize = 72;
  static const double _successIconSize = 48;

  @override
  void initState() {
    super.initState();
    // Eksikler `/users/me`'den hesaplanıyor; kullanıcı hiç yüklenmemiş ya da
    // başka cihazda değişmiş olabilir, o yüzden her açılışta sessizce
    // tazelenir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UserProvider>().load(silent: true);
    });
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  /// Başarı diyaloğu yalnız sunucu kaydı oluşturunca; hatada form kalır, ön
  /// yazı kaybolmasın.
  Future<void> _submit() async {
    final provider = context.read<ApplyProvider>();
    final coverLetter = _coverLetterController.text.trim();

    final succeeded = await provider.applyToJob(
      widget.job,
      coverLetter: coverLetter.isEmpty ? null : coverLetter,
    );

    if (!mounted) return;

    if (succeeded) {
      _showSuccessDialog(context);
      return;
    }

    // Ekran şartları önden gösteriyor ama başka cihazdan silinmiş olabilir;
    // hata kodu son söz.
    final requirement = ApplicationRequirement.fromErrorCode(
      provider.errorCode,
    );
    if (requirement != null) {
      await _showRequirementDialog(requirement);
      return;
    }

    AppToast.error(context, provider.errorMessage ?? 'Başvuru gönderilemedi.');
  }

  Future<void> _showRequirementDialog(
    ApplicationRequirement requirement,
  ) async {
    final user = context.read<UserProvider>().user;

    final goToScreen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text(
          requirement.title,
          style: dialogContext.textTheme.titleMedium,
        ),
        content: Text(
          requirement.description,
          style: dialogContext.textTheme.bodyMedium?.copyWith(
            color: dialogContext.textSecondary,
            height: _dialogLineHeight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Sonra'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(requirement.actionLabel),
          ),
        ],
      ),
    );

    if (goToScreen != true || !mounted || user == null) return;

    // Hedef ekranlar `/users/me`'yi tazeliyor; dönüşte uyarı kendiliğinden
    // kalkar.
    await context.push(requirement.route, extra: user);
  }

  static const double _dialogLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final applyProvider = context.watch<ApplyProvider>();
    final alreadyApplied = applyProvider.hasApplied(widget.job.id);
    // Eksik şart gönderimden önce söylenebiliyor; ön yazı boşuna yazılmasın.
    final userProvider = context.watch<UserProvider>();
    // Kullanıcı bilinmeden eksikler bilinmiyor: gönder kapalı. "Eksiği yok"
    // saymak sunucunun `APPLICANT_IDENTITY_NOT_VERIFIED` reddine yol açar.
    final user = userProvider.user;
    final readiness = ApplicationReadiness.of(user);
    final readinessKnown = user != null;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "İşe Başvur"),
      body: FormPageBody(
        child: Padding(
          padding: AppPadding.primaryHorizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSizes.spaceSmall),
              // Ritim: bölümler arası 24, başlıktan içeriğe 12.
              if (!readinessKnown)
                _readinessUnknown(userProvider)
              else if (!readiness.isReady)
                _readinessGroup(readiness),
              _sectionTitle('İlan'),
              const SizedBox(height: AppSizes.space),
              JobCard(job: widget.job, openDetailOnTap: false),
              const SizedBox(height: AppSizes.space),
              _coverLetterSection(),
              const SizedBox(height: AppSizes.spaceLarge),
              _requirementsGroup(),
              _termsRow(alreadyApplied: alreadyApplied),
              const SizedBox(height: AppSizes.spaceLarge),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ButtonNavbar(
        onPressed:
            (alreadyApplied ||
                !_agreedToTerms ||
                !readinessKnown ||
                !readiness.isReady ||
                applyProvider.isLoading)
            ? null
            : _submit,
        isLoading: applyProvider.isLoading,
        title: _submitLabel(
          alreadyApplied: alreadyApplied,
          readinessKnown: readinessKnown,
          readiness: readiness,
        ),
      ),
    );
  }

  String _submitLabel({
    required bool alreadyApplied,
    required bool readinessKnown,
    required ApplicationReadiness readiness,
  }) {
    if (alreadyApplied) return 'Zaten Başvurdunuz';
    if (!readinessKnown) return 'Başvuruyu Gönder';
    if (!readiness.isReady) return 'Önce Eksikleri Tamamla';
    return 'Başvuruyu Gönder';
  }

  /// Eksik şartlar; sunucu ilk eksikte durur ama hepsi gösterilir ki kaç adım
  /// olduğu baştan görülsün.
  Widget _readinessGroup(ApplicationReadiness readiness) {
    final user = context.read<UserProvider>().user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Başvurmadan önce tamamla'),
        const SizedBox(height: AppSizes.space),
        MyListGroup(
          children: [
            for (final requirement in readiness.missing)
              MyListTile(
                icon: _requirementIcon(requirement),
                title: requirement.title,
                onTap: user == null
                    ? null
                    : () => context.push(requirement.route, extra: user),
              ),
          ],
        ),
      ],
    );
  }

  /// Kullanıcı yükleniyorsa gösterge, yüklenemediyse sebep ve tekrar dene.
  Widget _readinessUnknown(UserProvider provider) {
    final Widget content = provider.hasError
        ? Row(
            children: [
              Expanded(
                child: Text(
                  'Başvuru şartlarını kontrol edemedik. '
                  '${provider.errorMessage ?? ''}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              TextButton(
                onPressed: () => provider.load(),
                child: const Text('Tekrar dene'),
              ),
            ],
          )
        : const Center(
            child: SizedBox(
              width: AppSizes.icon,
              height: AppSizes.icon,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );

    return Padding(
      key: const ValueKey('apply-readiness-unknown'),
      padding: const EdgeInsets.only(bottom: AppSizes.spaceLarge),
      child: content,
    );
  }

  static AppIconData _requirementIcon(ApplicationRequirement requirement) =>
      switch (requirement) {
        ApplicationRequirement.identity => AppIcons.personalCard,
        ApplicationRequirement.address => AppIcons.location,
        ApplicationRequirement.bankAccount => AppIcons.bank,
      };

  Widget _sectionTitle(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  // --------------------------------------------------------------- Ön yazı

  /// Diğer formlardaki çok satırlı alanın aynısı; gri dolgu devre dışı gibi
  /// durur.
  Widget _coverLetterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Ön yazı'),
        const SizedBox(height: AppSizes.space),
        MyTextfield(
          labelText: 'Ön yazı (isteğe bağlı)',
          controller: _coverLetterController,
          expands: true,
          height: _coverLetterHeight,
          borderRadius: AppRadius.innerCircular,
          inputFormatters: [
            LengthLimitingTextInputFormatter(_coverLetterMaxLength),
          ],
        ),
        const SettingsHint(
          'İşverene neden uygun olduğunu kısaca anlat. En fazla '
          '$_coverLetterMaxLength karakter.',
        ),
      ],
    );
  }

  // ---------------------------------------------------------- Gereksinimler

  /// Dokunulmayan satırlar; ikisi de özette zorunlu alan.
  Widget _requirementsGroup() {
    final job = widget.job;
    String label(bool required) => required ? 'Gerekli' : 'Gerekli değil';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gereksinimler'),
        const SizedBox(height: AppSizes.space),
        MyListGroup(
          children: [
            MyListTile(
              icon: AppIcons.work,
              title: 'Deneyim',
              value: label(job.experienceRequired),
            ),
            MyListTile(
              icon: AppIcons.shield,
              title: 'Sigorta',
              value: label(job.insuranceRequired),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Onay satırı

  Widget _termsRow({required bool alreadyApplied}) {
    void toggle() => setState(() => _agreedToTerms = !_agreedToTerms);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _checkboxSize,
          height: _checkboxSize,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: alreadyApplied
                ? null
                : (value) => setState(() => _agreedToTerms = value ?? false),
            activeColor: context.accentColor,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSizes.spaceTiny),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Expanded(
          child: GestureDetector(
            onTap: alreadyApplied ? null : toggle,
            child: Text(
              'Başvuru koşullarını ve kullanım şartlarını okudum, kabul ediyorum.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- Başarı diyaloğu

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _successCircleSize,
                height: _successCircleSize,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: _successIconSize,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Text(
                'Başvurunuz Alındı!',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                '${widget.job.title} için başvurunuz başarıyla gönderildi. '
                'İşveren değerlendirdikten sonra size bildirim göndereceğiz.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.go('/jobs');
                      },
                      style: _dialogButtonStyle(outlined: true),
                      child: const Text('İşlerime Git'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.space),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        context.go('/explore');
                      },
                      style: _dialogButtonStyle(outlined: false),
                      child: const Text('Keşfetmeye Dön'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _dialogButtonStyle({required bool outlined}) {
    final shape = const RoundedRectangleBorder(
      borderRadius: AppRadius.innerCircular,
    );
    final padding = const EdgeInsets.symmetric(vertical: AppSizes.spaceMedium);
    final textStyle = context.textTheme.labelLarge;

    return outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: context.accentColor,
            side: BorderSide(color: context.accentColor),
            shape: shape,
            padding: padding,
            textStyle: textStyle,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: context.accentColor,
            foregroundColor: context.onAccentColor,
            elevation: 0,
            shape: shape,
            padding: padding,
            textStyle: textStyle,
          );
  }
}
