import 'package:flutter/material.dart';

/// Boş alana dokununca klavyeyi kapatan sarmalayıcı.
///
/// iOS ve Android'de bir metin alanının dışına dokunmak odağı kendiliğinden
/// düşürmüyor; klavye ekranda kalıyor ve "Bitti" tuşu olmayan sayısal
/// klavyelerde kullanıcı sıkışıyor. Bu widget, altındaki ağaçta hiçbir
/// şeyin yakalamadığı dokunuşları alıp odağı bırakıyor. `translucent`
/// olduğu için buton, alan ve liste dokunuşları eskisi gibi hedefine gidiyor;
/// yalnızca boşa giden dokunuş buraya düşüyor.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  /// Odaklı alan varsa odağını bırakır; klavye bununla kapanır.
  static void dismiss() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: dismiss,
      child: child,
    );
  }
}
