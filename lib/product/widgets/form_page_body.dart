import 'package:flutter/material.dart';
import 'package:koala/product/widgets/dismiss_keyboard_on_tap.dart';

/// Metin alanı taşıyan sayfaların ortak gövdesi.
///
/// Üç şeyi tek yerde çözüyor:
/// - Gövde kaydırılabilir; klavye açılınca içerik ve gövdenin içindeki
///   düğme kaydırılarak klavyenin üstüne getirilebiliyor. `Scaffold`
///   varsayılan `resizeToAvoidBottomInset` ile küçüldüğünde odaklı alan
///   `EditableText`'in kendi kaydırmasıyla görünür kalıyor.
/// - Alt pay klavye kadar büyüyor. Küçülen bir `Scaffold` gövdeye klavye
///   payını vermiyor (`viewInsets` sıfır okunuyor), o yüzden bu pay yalnızca
///   `resizeToAvoidBottomInset: false` seçen ekranlarda devreye giriyor ve
///   çift boşluk oluşmuyor.
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
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return DismissKeyboardOnTap(
      child: SingleChildScrollView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: padding.copyWith(bottom: padding.bottom + keyboard),
        child: child,
      ),
    );
  }
}
