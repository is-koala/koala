import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// iOS'ta sayısal klavyenin üstüne çizilen "Bitti" şeridi.
///
/// iOS'un sayı, ondalık ve telefon klavyelerinde geri dönüş tuşu yok;
/// `TextInputAction.done` verilse de görünmüyor. Kullanıcı klavyeyi ancak
/// boş alana dokunarak kapatabiliyor, o da her ekranda mümkün değil. Bu
/// şerit `MyTextfield` tarafından yalnızca iOS'ta ve yalnızca [needsFor]
/// doğru döndüğünde klavyenin üstüne yerleştiriliyor; Android klavyeleri
/// kendi "Bitti" tuşunu taşıdığı için orada çizilmiyor.
class KeyboardDoneBar extends StatelessWidget {
  const KeyboardDoneBar({super.key, required this.onDone});

  final VoidCallback onDone;

  static const String label = 'Bitti';

  /// Verilen klavye türü iOS'ta geri dönüş tuşu taşımıyor mu.
  ///
  /// `numberWithOptions(signed: true)` sayı-noktalama klavyesini açıyor ve
  /// onda tuş var; yalnızca sayı tuş takımı, ondalık tuş takımı ve telefon
  /// tuş takımı tuşsuz.
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
