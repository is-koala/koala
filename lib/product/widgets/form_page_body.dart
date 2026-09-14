import 'package:flutter/material.dart';
import 'package:koala/product/widgets/dismiss_keyboard_on_tap.dart';
import 'package:koala/product/widgets/keyboard_insets.dart';

/// Metin alanı taşıyan sayfaların ortak gövdesi.
///
/// Üç şeyi tek yerde çözüyor:
/// - Gövde kaydırılabilir; klavye açılınca içerik ve gövdenin içindeki
///   düğme kaydırılarak klavyenin üstüne getirilebiliyor. `Scaffold`
///   varsayılan `resizeToAvoidBottomInset` ile küçüldüğünde odaklı alan
///   `EditableText`'in kendi kaydırmasıyla görünür kalıyor.
/// - Alt pay klavye kadar büyüyor ([KeyboardInsets]: sistem klavyesi + iOS
///   "Bitti" şeridi). Küçülen bir `Scaffold` gövdeye klavye payını vermiyor
///   (`viewInsets` sıfır okunuyor), o yüzden sistem payı yalnızca
///   `resizeToAvoidBottomInset: false` seçen ekranlarda devreye giriyor ve
///   çift boşluk oluşmuyor. Şerit payı ise `Scaffold`'un alt çubuğu yoksa
///   ekleniyor; çubuk varsa gövde zaten onun üstünde bitiyor.
/// - Boş alana dokununca ya da liste sürüklenince klavye kapanıyor.
///
/// Alt CTA `Scaffold.bottomNavigationBar`'da duruyorsa `ButtonNavbar`
/// klavyenin üstüne kendisi çıkıyor; gövdenin içindeyse kaydırılarak
/// erişiliyor. İkisi de "düğme klavyenin arkasında kalmasın" kabulünü
/// karşılıyor.
class FormPageBody extends StatelessWidget {
  const FormPageBody({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final Widget child;

  /// İçeriğin kenar payı; klavye payı bunun üstüne ekleniyor.
  final EdgeInsets padding;

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final hasBottomBar =
        Scaffold.maybeOf(context)?.widget.bottomNavigationBar != null;

    return KeyboardInsetsBuilder(
      builder: (context, keyboard) {
        final bottom = hasBottomBar
            ? MediaQuery.viewInsetsOf(context).bottom
            : keyboard;
        return DismissKeyboardOnTap(
          child: SingleChildScrollView(
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding.copyWith(bottom: padding.bottom + bottom),
            child: child,
          ),
        );
      },
    );
  }
}
