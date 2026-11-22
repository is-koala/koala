import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_sizes.dart';

/// Klavyenin gerçekten kapladığı yükseklik. `viewInsets` iOS'taki "Bitti"
/// şeridini (44 pt) bilmiyor; alt çubuk, form gövdesi ve imleç payı değeri
/// buradan okuyor. Şeridin görünürlüğü [doneBarVisible]'da.
class KeyboardInsets {
  KeyboardInsets._();

  static final ValueNotifier<bool> doneBarVisible = ValueNotifier<bool>(false);

  /// Sistem klavyesi, araya giren `Scaffold`'dan bağımsız: küçülen `Scaffold`
  /// gövdesinin `viewInsets`'ini siliyor.
  static double systemBottomOf(BuildContext context) =>
      MediaQueryData.fromView(View.of(context)).viewInsets.bottom;

  static double doneBarOf(BuildContext context) {
    if (!doneBarVisible.value || systemBottomOf(context) <= 0) return 0;
    return AppSizes.keyboardToolbar;
  }

  /// Bu bağlamın gördüğü klavye payı artı şerit.
  static double bottomOf(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom + doneBarOf(context);
}

/// [KeyboardInsets.bottomOf]'u şerit bayrağını dinleyerek verir.
class KeyboardInsetsBuilder extends StatelessWidget {
  const KeyboardInsetsBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, double bottom) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KeyboardInsets.doneBarVisible,
      builder: (context, _, _) =>
          builder(context, KeyboardInsets.bottomOf(context)),
    );
  }
}
