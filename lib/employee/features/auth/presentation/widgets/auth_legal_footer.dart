import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Giriş ve kayıt sayfalarının en altındaki kullanım şartları satırı.
///
/// İki sayfada da aynı; metin `RichText` çünkü cümlenin ortasındaki iki
/// bağlantı ayrı ayrı tıklanabilir olmalı.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final baseStyle = context.textTheme.labelSmall?.copyWith(
      color: context.textSecondary,
      height: 1.5,
    );
    final linkStyle = baseStyle?.copyWith(
      color: context.accentColor,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: AppPadding.authFooter,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'Devam ederek '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {},
                child: Text('Kullanım Şartları', style: linkStyle),
              ),
            ),
            const TextSpan(text: ' ve '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () {},
                child: Text('Gizlilik Politikası', style: linkStyle),
              ),
            ),
            const TextSpan(text: "'nı kabul etmiş olursunuz."),
          ],
        ),
      ),
    );
  }
}
