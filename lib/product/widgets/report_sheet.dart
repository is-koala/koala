import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/report_service.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Kullanıcı, ilan ve mesaj şikayetlerinin ortak formu.
///
/// `ReasonDialog` bu iş için yetmiyordu: orada gerekçe serbest metin, burada
/// sunucunun `ReportReason` listesinden **seçiliyor**.
///
/// Gönderimi sheet'in kendisi yapıyor. Dört giriş noktası var ve her birinde
/// aynı hata/başarı işlemesini tekrarlamak, dördünün bir yerde ayrışması
/// demekti.
///
/// ```dart
/// ReportSheet.show(
///   context,
///   ReportTarget.user(userId: chat.counterpartId, name: chat.name),
/// );
/// ```
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.target});

  /// Şikayetin işaret ettiği kayıt: kullanıcı, ilan ya da mesaj.
  final ReportTarget target;

  /// Sunucunun `@Size(max = 2000)` sınırı. İstemcide de tutuluyor ki
  /// kullanıcı 2000. karakterden sonra yazdığını gönderirken kaybetmesin.
  static const int descriptionLimit = 2000;

  /// Sheet'i açar. Şikayet gönderildiyse `true`, vazgeçildiyse `null` döner.
  static Future<bool?> show(BuildContext context, ReportTarget target) {
    return AppBottomSheet.show<bool>(
      context,
      builder: (_) => ReportSheet(target: target),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  /// Tembel kuruluyor: form açılıp vazgeçilirse ağ istemcisine hiç
  /// dokunulmuyor.
  late final ReportService _service = ReportService();

  final TextEditingController _description = TextEditingController();

  ReportReason? _reason;
  bool _isSending = false;

  /// Formun ekranın en fazla ne kadarını kaplayabileceği. Sekiz gerekçe,
  /// açıklama alanı ve düğme küçük ekranlarda sığmıyor; sınır olmadan
  /// `Column` taşıyor, sınırla içerik kayıyor.
  static const double _maxHeightRatio = 0.72;

  /// Çok satırlı açıklama alanının yüksekliği.
  static const double _descriptionHeight = 96;

  /// Seçili gerekçenin zemin opaklığı ve halkası; `ThemeModeSheet` ile aynı
  /// kurgu.
  static const double _selectedTintAlpha = 0.1;
  static const double _selectedBorderWidth = 2.0;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: widget.target.sheetTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _maxHeightRatio,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.target.description,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceMedium),
                Text('Gerekçe', style: context.textTheme.titleSmall),
                const SizedBox(height: AppSizes.spaceSmall),
                // Bilinmeyen gerekçe listede yok: kodu boş, sunucuya
                // gönderilse `400` olurdu.
                for (final reason in ReportReason.selectable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
                    child: _reasonRow(reason),
                  ),
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  'Açıklama (isteğe bağlı)',
                  style: context.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSizes.spaceSmall),
                MyTextfield(
                  labelText: 'Ne olduğunu kısaca anlat',
                  controller: _description,
                  expands: true,
                  height: _descriptionHeight,
                  borderRadius: AppRadius.innerCircular,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(
                      ReportSheet.descriptionLimit,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceLarge),
                MyButton(
                  title: 'Gönder',
                  isLoading: _isSending,
                  // Gerekçe zorunlu: sunucudan `400` beklemek yerine
                  // istemci durduruyor.
                  onPressed: _reason == null ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Gerekçe satırı.
  ///
  /// `RadioListTile` **kullanılamıyor**: içeride bir `ListTile` kuruyor ve
  /// `AppBottomSheet`'in renkli kabuğu araya girdiği için Flutter
  /// "background color or ink splashes may be invisible" assert'ini
  /// düşürüyor. Kurgu `ThemeModeSheet._option` ile aynı.
  Widget _reasonRow(ReportReason reason) {
    final isSelected = _reason == reason;
    final accent = context.accentColor;

    return Material(
      color: isSelected
          ? accent.withValues(alpha: _selectedTintAlpha)
          : context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: _isSending ? null : () => setState(() => _reason = reason),
        child: Container(
          padding: AppPadding.tile,
          decoration: BoxDecoration(
            borderRadius: AppRadius.innerCircular,
            border: isSelected
                ? Border.all(color: accent, width: _selectedBorderWidth)
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  reason.displayName,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? accent : context.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                AppIcon(
                  AppIcons.tick,
                  color: accent,
                  size: AppSizes.iconMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _isSending) return;

    setState(() => _isSending = true);

    // Boş açıklama gövdeye hiç konmuyor; `""` göndermek "yazdı ama boş
    // bıraktı" gibi kaydedilirdi.
    final description = _description.text.trim();

    try {
      await _service.createReport(
        reportedUserId: widget.target.reportedUserId,
        jobId: widget.target.jobId,
        messageId: widget.target.messageId,
        reason: reason,
        description: description.isEmpty ? null : description,
      );

      if (!mounted) return;
      // Toast önce gösteriliyor: `ScaffoldMessenger` sheet'in üstünde, sheet
      // kapandıktan sonra da ekranda kalıyor.
      AppToast.success(context, 'Şikayetin alındı, teşekkürler.');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      // Sunucu `Accept-Language: tr` ile zaten Türkçe döndürüyor —
      // "Kendinizi şikayet edemezsiniz." gibi. Metni yeniden yazmıyoruz.
      AppToast.error(context, error.message);
    }
  }
}
