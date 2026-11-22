import 'package:material_ui/material_ui.dart';
import 'package:koala/product/widgets/dismiss_keyboard_on_tap.dart';
import 'package:koala/product/widgets/keyboard_insets.dart';

/// Metin alanı taşıyan sayfaların ortak gövdesi: kaydırılabilir, alt pay klavye
/// kadar ([KeyboardInsets]) büyür, boşa dokunmak ya da sürüklemek klavyeyi
/// kapatır.
///
/// Küçülen `Scaffold` gövdeye `viewInsets` vermediği için sistem payı yalnız
/// `resizeToAvoidBottomInset: false` ekranlarda ekleniyor; çift boşluk olmuyor.
/// Şerit payı alt çubuk yoksa ekleniyor.
class FormPageBody extends StatelessWidget {
  const FormPageBody({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final Widget child;

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
