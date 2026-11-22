import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Mesaj düğmesinin yerine geçen açıklama: sunucu ödeme emanete geçmeden
/// sohbeti reddediyor, `403` yedirmek yerine sebep yazılıyor. Metin
/// `MessagingAvailability.noteFor`'dan.
class MessagingGateNote extends StatelessWidget {
  const MessagingGateNote({
    super.key,
    required this.message,
    this.color,
    this.action,
  });

  final String message;

  /// Verilmezse ikincil metin rengi.
  final Color? color;

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
