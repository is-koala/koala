import 'package:material_ui/material_ui.dart';

/// Boş alana dokununca klavyeyi kapatır. Platformlar odağı kendiliğinden
/// düşürmüyor ve "Bitti" tuşsuz sayısal klavyede kullanıcı sıkışıyor.
/// `translucent`, yalnız boşa giden dokunuşu yakalar.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

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
