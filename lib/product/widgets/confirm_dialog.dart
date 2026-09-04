import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Geri alınamayan işlemler için onay kutusu.
///
/// Silme, oturum kapatma ve yönlendirme kutuları aynı biçimi üç ayrı yerde
/// kuruyordu; biçimi tek yerde tutmak metinlerin de aynı tonda kalmasını
/// sağlıyor.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    this.isDestructive = true,
    this.cancelLabel = 'Vazgeç',
  });

  final String title;
  final String message;

  /// Onay düğmesinin metni. "Tamam" değil, ne olacağını söyleyen bir fiil
  /// olmalı — kullanıcı düğmeye bakarak karar veriyor.
  final String actionLabel;

  /// Sonuç geri alınamıyorsa onay düğmesi kırmızı. Yönlendirme gibi zararsız
  /// onaylarda kapatılıyor.
  final bool isDestructive;

  final String cancelLabel;

  /// Kutuyu açar; onaylanırsa `true`, vazgeçilir ya da dışına dokunulursa
  /// `null` döner. Çağıranlar `!= true` ile kontrol ediyor, böylece iki
  /// durum ayrı ayrı ele alınmak zorunda kalmıyor.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String actionLabel,
    bool isDestructive = true,
    String cancelLabel = 'Vazgeç',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        actionLabel: actionLabel,
        isDestructive: isDestructive,
        cancelLabel: cancelLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.secondaryCircular,
      ),
      title: Text(title, style: context.textTheme.titleMedium),
      content: Text(
        message,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.textSecondary,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: isDestructive
              ? TextButton.styleFrom(foregroundColor: AppColors.danger)
              : null,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}
