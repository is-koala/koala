import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Bir alanın altındaki soluk açıklama satırı.
class SettingsHint extends StatelessWidget {
  const SettingsHint(this.text, {super.key, this.padding = fieldPadding});

  /// Üstte alanla arasında pay, solda alanın metniyle hizalı girinti.
  static const EdgeInsets fieldPadding = EdgeInsets.only(
    top: AppSizes.spaceTiny,
    left: AppSizes.space,
  );

  final String text;

  /// Varsayılan [fieldPadding]; kendi kutusundaki ipuçları farklı hizalanıyor.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.textTertiary,
        ),
      ),
    );
  }
}
