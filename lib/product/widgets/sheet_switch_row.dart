import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Bottom sheet içindeki açma/kapama satırı. `SwitchListTile` değil: içindeki
/// `ListTile` renkli kabukta "ink splashes may be invisible" assert'i veriyor.
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
        // Etikete dokunmak da çeviriyor; `SwitchListTile`'dan kaybedilen tek
        // davranış buydu.
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
