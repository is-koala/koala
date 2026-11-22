import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// "Ulaşım planı ekle" (#197); ilan formu ve detayı ortak.
class BTransportAddButton extends StatelessWidget {
  const BTransportAddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: AppIcon(
          AppIcons.bus,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        label: const Text('Ulaşım planı ekle'),
        style: context.accentOutlinedButtonStyle,
      ),
    );
  }
}
