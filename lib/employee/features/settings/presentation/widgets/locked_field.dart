import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Değeri değiştirilemeyen bir form satırı: solda etiket, sağda değer.
///
/// Kimlik ekranı çipten türeyen beş alanı bununla çiziyor. Kapalı bir
/// `MyTextfield` yerine ayrı bir widget, çünkü metin alanının bir
/// `TextEditingController`'ı var ve o denetleyici ekranın gösterdiği şeyi
/// beyandan bağımsız değiştirebilirdi; burada değer doğrudan geçiliyor ve
/// başka bir kaynağı yok. Görünüm doğum tarihi satırıyla aynı — beş alan
/// birlikte "karttan okunan özet" gibi okunsun diye.
///
/// Ekran okuyucuya **tek düğüm** olarak gidiyor: etiket `label`, değer
/// `value`, salt okunur. İki `Text` iki ayrı düğüm olsaydı okuyucu "Ad" ve
/// "ÇAĞRI"yı birbirinden bağımsız iki öğe gibi duyurur, hangisinin neyin
/// değeri olduğu kaybolurdu.
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
      // İki `Text`'in kendi düğümleri yukarıdakinin altına ayrıca eklenmesin;
      // ekran okuyucu aynı şeyi iki kez duymasın.
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
            // Kalan genişliğin tamamı değere: uzun bir ad taşmak yerine sağa
            // yaslı biçimde alt satıra iniyor.
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
