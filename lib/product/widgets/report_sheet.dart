import 'package:material_ui/material_ui.dart';
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

/// Kullanıcı, ilan ve mesaj şikayeti formu; gerekçe sunucunun `ReportReason`
/// listesinden seçiliyor. Gönderimi sheet yapıyor ki dört giriş noktası
/// ayrışmasın.
///
/// ```dart
/// ReportSheet.show(context, ReportTarget.user(userId: id, name: name));
/// ```
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key, required this.target});

  final ReportTarget target;

  /// Sunucunun `@Size(max = 2000)` sınırı; kullanıcı fazlasını gönderirken
  /// kaybetmesin.
  static const int descriptionLimit = 2000;

  /// Gönderildiyse `true`, vazgeçildiyse `null`.
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
  /// Tembel: vazgeçilen form ağ istemcisine dokunmasın.
  late final ReportService _service = ReportService();

  final TextEditingController _description = TextEditingController();

  ReportReason? _reason;
  bool _isSending = false;

  /// Sekiz gerekçe, açıklama ve düğme küçük ekrana sığmıyor; sınırla içerik
  /// kayıyor.
  static const double _maxHeightRatio = 0.72;

  static const double _descriptionHeight = 96;

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
                // Bilinmeyen gerekçenin kodu boş; gönderilse `400` olurdu.
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
                  onPressed: _reason == null ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `RadioListTile` değil: içindeki `ListTile` renkli kabukta "ink splashes
  /// may be invisible" assert'i veriyor.
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

    // Boş açıklama gövdeye konmuyor; `""` "boş bıraktı" diye kaydedilirdi.
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
      // Toast önce: `ScaffoldMessenger` sheet kapandıktan sonra da ekranda.
      AppToast.success(context, 'Şikayetin alındı, teşekkürler.');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      AppToast.error(context, error.message);
    }
  }
}
