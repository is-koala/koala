import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Değiştirilemeyen form satırı: solda etiket, sağda değer. Kapalı
/// `MyTextfield` değil, çünkü denetleyici değeri beyandan bağımsız
/// değiştirebilirdi. Ekran okuyucuya tek düğüm olarak gidiyor ki etiket ile
/// değer ayrı öğeler gibi duyulmasın.
class LockedField extends StatelessWidget {
  const LockedField({super.key, required this.label, required this.value});

  final String label;

  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value,
      readOnly: true,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            // Uzun ad taşmak yerine alt satıra iniyor.
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
