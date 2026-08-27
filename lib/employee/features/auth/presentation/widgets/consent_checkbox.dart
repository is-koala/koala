import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Kayıt ekranındaki tek bir sözleşme onayı.
///
/// Zorunlu onaylar sonuna kırmızı bir yıldız alıyor; metnin tamamı
/// tıklanabilir, böylece küçük kutuyu tutturmak gerekmiyor.
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isMandatory = false,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isMandatory;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            onChanged: (isChecked) => onChanged(isChecked ?? false),
            activeColor: context.accentColor,
            checkColor: context.onAccentColor,
            side: BorderSide(color: context.dividerColor),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                children: isMandatory
                    ? [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ]
                    : null,
              ),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
        ],
      ),
    );
  }
}
