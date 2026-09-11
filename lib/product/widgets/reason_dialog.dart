import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Gerekçe soran onay kutusu.
///
/// İptal ve uyuşmazlık uçlarının ikisi de gerekçeyi **zorunlu** tutuyor ve
/// boş gerekçeyi `400` ile reddediyor; bu yüzden onay butonu alan dolana
/// kadar kapalı duruyor. Sunucudan hata almadan önce burada durdurmak
/// kullanıcıya bir gidiş dönüş kazandırıyor.
///
/// İki uygulama da kullanıyor: çalışan işi iptal ederken, işveren hem iptal
/// ederken hem uyuşmazlık açarken.
///
/// ```dart
/// final reason = await ReasonDialog.show(
///   context,
///   title: 'İşi iptal et',
///   description: 'İptal geri alınamaz.',
///   fieldLabel: 'İptal gerekçen',
///   confirmLabel: 'İptal Et',
/// );
/// ```
class ReasonDialog extends StatefulWidget {
  const ReasonDialog({
    super.key,
    required this.title,
    required this.description,
    required this.fieldLabel,
    required this.confirmLabel,
    this.isDestructive = true,
    this.initialText,
    this.maxLength,
  });

  final String title;

  /// Kullanıcının ne olacağını anlaması için başlığın altındaki metin.
  final String description;

  final String fieldLabel;
  final String confirmLabel;

  /// Onay butonunun kırmızı olup olmayacağı. Geri alınamayan işlemlerde
  /// kırmızı; nötr bir talepte (uyuşmazlık açma) değil.
  final bool isDestructive;

  /// Alanı açıkken doldurmak için. Not güncellemede önceki metin burada.
  final String? initialText;

  /// İstemci tarafı uzunluk tavanı. Sunucu da ayrıca doğrular.
  final int? maxLength;

  /// Kutuyu açar. Vazgeçilirse `null`, onaylanırsa girilen gerekçe döner.
  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String description,
    required String fieldLabel,
    required String confirmLabel,
    bool isDestructive = true,
    String? initialText,
    int? maxLength,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: title,
        description: description,
        fieldLabel: fieldLabel,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        initialText: initialText,
        maxLength: maxLength,
      ),
    );
  }

  @override
  State<ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<ReasonDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText ?? '',
  );

  /// Açıklama metninin satır aralığı; çok satırlı gövde sıkışık duruyordu.
  static const double _lineHeight = 1.4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();

    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.secondaryCircular,
      ),
      title: Text(widget.title, style: context.textTheme.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.description,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: _lineHeight,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          MyTextfield(
            labelText: widget.fieldLabel,
            controller: _controller,
            onChanged: (_) => setState(() {}),
            inputFormatters: [
              if (widget.maxLength != null)
                LengthLimitingTextInputFormatter(widget.maxLength),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        TextButton(
          // Gerekçe zorunlu; boşken buton kapalı.
          onPressed: reason.isEmpty
              ? null
              : () => Navigator.pop(context, reason),
          style: TextButton.styleFrom(
            foregroundColor: widget.isDestructive
                ? AppColors.danger
                : context.accentColor,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
