import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// iOS sayısal klavyelerinin üstündeki "Bitti" şeridi: bu klavyelerde geri
/// dönüş tuşu yok. Android klavyeleri kendi tuşunu taşıdığı için yalnız iOS'ta.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key, required this.onDone});

  final VoidCallback onDone;

  static const String label = 'Bitti';

  /// Klavye iOS'ta geri dönüş tuşsuz mu. `signed: true` klavyede tuş var; sayı,
  /// ondalık ve telefon tuş takımları tuşsuz.
  static bool needsFor(TextInputType type) {
    if (type == TextInputType.phone) return true;
    return type.index == TextInputType.number.index && type.signed != true;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.elevatedColor,
      child: Container(
        height: AppSizes.keyboardToolbar,
        padding: AppPadding.primaryHorizontal,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.dividerColor)),
        ),
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: onDone,
          child: Text(
            label,
            style: context.textTheme.labelLarge?.copyWith(
              color: context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
