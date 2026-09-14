import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Mesaj düğmesinin yerine geçen kısa açıklama.
///
/// Sunucu ödeme emanete geçmeden sohbeti reddediyor; düğmeyi açık bırakıp
/// `403` yedirmek yerine sebebi burada yazılıyor. İki kabuk da kullanıyor:
/// çalışanın "İşlerim" satırı ve işverenin başvuran kartı. Metin
/// `MessagingAvailability.noteFor` ile tarafa göre seçiliyor.
///
/// [action] isteğe bağlı kısayol — işverende ödeme akışını başlatan düğme.
class MessagingGateNote extends StatelessWidget {
  const MessagingGateNote({
    super.key,
    required this.message,
    this.color,
    this.action,
  });

  final String message;

  /// Metin ve ikon rengi. Verilmezse ikincil metin rengi; yeşil zemindeki
  /// satırlar `onAccent` geçiyor.
  final Color? color;

  /// Açıklamanın yanındaki kısayol; yoksa yalnızca metin.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? context.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIcon(AppIcons.info, size: AppSizes.iconSmall, color: foreground),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            message,
            style: context.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ),
        ?action,
      ],
    );
  }
}
