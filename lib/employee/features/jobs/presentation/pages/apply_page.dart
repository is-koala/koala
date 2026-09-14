import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/jobs/models/application_readiness.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
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

  /// İş bilgileri kartının zemin ve kenarlık opaklıkları; kart sayfadan
  /// ayrışsın ama başvuru formunun önüne geçmesin.
  static const double _jobCardFill = 0.08;
  static const double _jobCardBorder = 0.2;

  /// Kategori rozetinin zemin opaklığı.
  static const double _categoryTintAlpha = 0.15;

  /// Ön yazı alanının satır ve karakter sınırı.
  static const int _coverLetterLines = 5;
  static const int _coverLetterMaxLength = 500;

  /// Onay kutusunun dokunma alanı.
  static const double _checkboxSize = 24;

  /// Başarı diyaloğundaki tik dairesi.
  static const double _successCircleSize = 72;
  static const double _successIconSize = 48;

  @override
  void dispose() {
    _coverLetterController.dispose();
    super.dispose();
  }

  /// Başvuruyu gönderir.
  ///
  /// Başarı diyaloğu yalnızca sunucu kaydı oluşturduğunda açılıyor; hata
  /// durumunda kullanıcı formda kalıyor ki yazdığı ön yazı kaybolmasın.
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

    // Sunucu başvuru anında kimlik, adres ve IBAN'ı sırayla kontrol ediyor.
    // Ekran bunları önden de gösteriyor ama kullanıcı arada başka bir
    // cihazdan bilgisini silmiş olabilir; hata kodu son sözü söylüyor.
    final requirement = ApplicationRequirement.fromErrorCode(
      provider.errorCode,
    );
    if (requirement != null) {
      await _showRequirementDialog(requirement);
      return;
    }

    AppToast.error(context, provider.errorMessage ?? 'Başvuru gönderilemedi.');
  }

  /// Eksik şartı anlatıp ilgili ekrana götürür.
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

    // Ekranlar `/users/me`'yi tazeliyor; dönüşte kullanıcı güncel oluyor ve
    // uyarı şeridi kendiliğinden kayboluyor.
    await context.push(requirement.route, extra: user);
  }

  /// Uyarı metinlerinin satır aralığı.
  static const double _dialogLineHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    final applyProvider = context.watch<ApplyProvider>();
    final alreadyApplied = applyProvider.hasApplied(widget.job.id);
    // Üç şart da `/users/me`'de duruyor, o yüzden eksik olan başvuru
    // gönderilmeden söylenebiliyor: kullanıcı ön yazıyı boşuna yazmıyor.
    final readiness = ApplicationReadiness.of(
      context.watch<UserProvider>().user,
    );

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
              if (!readiness.isReady) ...[
                _readinessCard(readiness),
                const SizedBox(height: AppSizes.spaceMedium),
              ],
              _jobCard(),
              const SizedBox(height: AppSizes.spaceLarge),
              _coverLetterSection(),
              const SizedBox(height: AppSizes.spaceMedium),
              if (_hasRequirements) ...[
                _sectionTitle('Gereksinimler'),
                const SizedBox(height: AppSizes.space),
                _requirementsCard(),
                const SizedBox(height: AppSizes.spaceMedium),
              ],
              _termsRow(alreadyApplied: alreadyApplied),
              const SizedBox(height: AppSizes.navBarClearance),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ButtonNavbar(
        onPressed:
            (alreadyApplied ||
                !_agreedToTerms ||
                !readiness.isReady ||
                applyProvider.isLoading)
            ? null
            : _submit,
        isLoading: applyProvider.isLoading,
        title: _submitLabel(
          alreadyApplied: alreadyApplied,
          readiness: readiness,
        ),
      ),
    );
  }

  String _submitLabel({
    required bool alreadyApplied,
    required ApplicationReadiness readiness,
  }) {
    if (alreadyApplied) return 'Zaten Başvurdunuz';
    if (!readiness.isReady) return 'Önce Eksikleri Tamamla';
    return 'Başvuruyu Gönder';
  }

  /// Eksik şartların listesi.
  ///
  /// Sunucu şartları sırayla kontrol edip ilk eksikte duruyor; burada hepsi
  /// birden gösteriliyor ki kullanıcı kaç adım olduğunu baştan görsün.
  Widget _readinessCard(ApplicationReadiness readiness) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: _jobCardFill),
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: _jobCardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Başvurabilmen için eksiklerin var',
            style: context.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          for (final requirement in readiness.missing)
            _readinessRow(requirement),
        ],
      ),
    );
  }

  Widget _readinessRow(ApplicationRequirement requirement) {
    final user = context.read<UserProvider>().user;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.warning,
            size: AppSizes.iconSmall,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(requirement.title, style: context.textTheme.bodyMedium),
          ),
          TextButton(
            onPressed: user == null
                ? null
                : () => context.push(requirement.route, extra: user),
            child: Text(requirement.actionLabel),
          ),
        ],
      ),
    );
  }

  /// Başvuru ekranı yalnızca özet yanıttaki gereksinimleri gösteriyor.
  /// Yaş aralığı, kıyafet ve açık adres `GET /jobs/{id}`'de; kullanıcı onları
  /// başvurmadan önce detay ekranında görüyor, form için ikinci istek atmaya
  /// değmiyor.
  bool get _hasRequirements => true;

  Widget _sectionTitle(String title) =>
      Text(title, style: context.textTheme.titleSmall);

  // ----------------------------------------------------------- İş bilgileri

  Widget _jobCard() {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: _jobCardFill),
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(
          color: context.accentColor.withValues(alpha: _jobCardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _categoryBadge(),
          const SizedBox(height: AppSizes.space),
          Text(
            widget.job.title,
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            widget.job.company ?? '',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.space),
          _priceAndLocationRow(),
          if (widget.job.startDateTime != null) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _dateRow(),
          ],
        ],
      ),
    );
  }

  Widget _categoryBadge() {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: widget.job.category.color.withValues(alpha: _categoryTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            widget.job.category.icon,
            size: AppSizes.iconSmall,
            color: widget.job.category.color,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            widget.job.category.displayName,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.job.category.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceAndLocationRow() {
    return Row(
      children: [
        Icon(
          Icons.monetization_on_outlined,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          '₺${widget.job.price.toStringAsFixed(0)}',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
        Icon(
          Icons.location_on_outlined,
          size: AppSizes.iconSmall,
          color: context.textSecondary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            widget.job.locationLabel ?? '-',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _dateRow() {
    final start = widget.job.startDateTime!;
    final end = widget.job.endDateTime;
    final style = context.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
    );

    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: AppSizes.iconSmall,
          color: context.textSecondary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(_formatDate(start), style: style),
        if (end != null) Text(' - ${_formatDate(end)}', style: style),
      ],
    );
  }

  String _formatDate(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';

  // --------------------------------------------------------------- Ön yazı

  Widget _coverLetterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Ön Yazı (Opsiyonel)'),
        const SizedBox(height: AppSizes.spaceTiny),
        Text(
          'İşveren size neden uygun olduğunuzu kısaca anlatın',
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSizes.space),
        TextField(
          controller: _coverLetterController,
          maxLines: _coverLetterLines,
          maxLength: _coverLetterMaxLength,
          decoration: InputDecoration(
            hintText: 'Kendinizi tanıtın, deneyimlerinizden bahsedin...',
            hintStyle: context.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
            filled: true,
            fillColor: context.tileColor,
            border: _coverLetterBorder(context.dividerColor),
            enabledBorder: _coverLetterBorder(context.dividerColor),
            focusedBorder: _coverLetterBorder(context.accentColor, width: 1.5),
            contentPadding: AppPadding.primaryAll,
          ),
          style: context.textTheme.bodyMedium,
        ),
      ],
    );
  }

  OutlineInputBorder _coverLetterBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.innerCircular,
        borderSide: BorderSide(color: color, width: width),
      );

  // ---------------------------------------------------------- Gereksinimler

  Widget _requirementsCard() {
    final job = widget.job;

    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        children: [
          // İkisi de özet yanıtta zorunlu alan: her zaman çizilebiliyorlar.
          _requirementRow(
            Icons.work_outline,
            'Deneyim',
            job.experienceRequired ? 'Gerekli' : 'Gerekli Değil',
          ),
          _requirementRow(
            Icons.health_and_safety_outlined,
            'Sigorta',
            job.insuranceRequired ? 'Gerekli' : 'Gerekli Değil',
          ),
        ],
      ),
    );
  }

  Widget _requirementRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMedium, color: context.textSecondary),
          const SizedBox(width: AppSizes.space),
          Text(
            '$label: ',
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
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
