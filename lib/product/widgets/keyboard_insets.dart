import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_sizes.dart';

/// Klavyenin ekranın altında gerçekten kapladığı yükseklik.
///
/// Sistem yalnızca kendi klavyesini bildiriyor (`viewInsets.bottom`); iOS'ta
/// sayısal alanların üstüne çizilen "Bitti" şeridi (`KeyboardDoneBar`) onun
/// üstünde 44 pt daha yer kaplıyor ve `MediaQuery` bundan habersiz. Alt
/// çubuk, form gövdesi ve odaklı alanın kaydırma payı bu değeri buradan
/// okuyor; aksi hâlde düğme ve imleç şeridin arkasında kalıyor.
///
/// Şeridin görünürlüğü tek bir bayrakta ([doneBarVisible]); `MyTextfield`
/// şeridi koyarken açıyor, kaldırırken kapatıyor. Okuyanlar
/// [KeyboardInsetsBuilder] ile dinliyor ki bayrak değişince yeniden ölçülsün.
class KeyboardInsets {
  KeyboardInsets._();

  /// "Bitti" şeridi şu anda `Overlay`'de mi.
  static final ValueNotifier<bool> doneBarVisible = ValueNotifier<bool>(false);

  /// Sistem klavyesinin yüksekliği, araya giren `Scaffold`'dan bağımsız:
  /// küçülen bir `Scaffold` gövdesinin `MediaQuery`'sinden `viewInsets`'i
  /// siler, şerit ise klavye açık olduğu sürece orada.
  static double systemBottomOf(BuildContext context) =>
      MediaQueryData.fromView(View.of(context)).viewInsets.bottom;

  /// Şeridin eklediği pay: klavye açık ve şerit görünürken şerit boyu.
  static double doneBarOf(BuildContext context) {
    if (!doneBarVisible.value || systemBottomOf(context) <= 0) return 0;
    return AppSizes.keyboardToolbar;
  }

  /// Bu bağlamın gördüğü klavye payı artı şerit. Küçülen `Scaffold`'un
  /// gövdesinde sistem payı sıfır okunur, geriye yalnız şerit kalır.
  static double bottomOf(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom + doneBarOf(context);
}

/// [KeyboardInsets.bottomOf] değerini şerit bayrağını dinleyerek verir.
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
