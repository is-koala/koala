import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Bottom sheet içindeki açma/kapama satırı.
///
/// `SwitchListTile` **kullanılamıyor**: içeride bir `ListTile` kuruyor ve
/// `AppBottomSheet`'in renkli kabuğu araya girdiği için Flutter
/// "background color or ink splashes may be invisible" assert'ini düşürüyor.
/// Projedeki bütün dokunulabilir satırlar gibi bu da `Material` + `InkWell`
/// — `ThemeModeSheet._option` ile aynı kurgu.
class SheetSwitchRow extends StatelessWidget {
  const SheetSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        // Etikete dokunmak da anahtarı çeviriyor; `SwitchListTile`'ın
        // kaybedilen tek davranışı buydu.
        onTap: () => onChanged(!value),
        child: Padding(
          padding: AppPadding.tile,
          child: Row(
            children: [
              Expanded(child: Text(title, style: context.textTheme.bodyMedium)),
              const SizedBox(width: AppSizes.space),
              Switch.adaptive(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
