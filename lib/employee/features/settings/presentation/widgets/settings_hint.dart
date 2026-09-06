import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Bir alanın altındaki soluk açıklama satırı.
///
/// Ayarlar ekranlarının dördü de (hesap bilgileri, kimlik doğrulama, şifre
/// değiştirme ve doğrulama kodu) aynı satırı kendi içinde yeniden kuruyordu;
/// üçü birebir aynı, dördüncüsü yalnızca boşluğuyla farklıydı. Tek yerde
/// durunca ipucu metinlerinin tonu ve hizası da tek yerden değişiyor.
class SettingsHint extends StatelessWidget {
  const SettingsHint(this.text, {super.key, this.padding = fieldPadding});

  /// Bir form alanının hemen altına oturan ipucunun boşluğu: üstte alanla
  /// arasında nefes payı, solda alanın metniyle hizalayan girinti.
  static const EdgeInsets fieldPadding = EdgeInsets.only(
    top: AppSizes.spaceTiny,
    left: AppSizes.space,
  );

  final String text;

  /// Satırın boşluğu. Alanın altında değil de kendi kutusunun içinde duran
  /// ipuçları farklı hizalanıyor; varsayılan [fieldPadding].
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
