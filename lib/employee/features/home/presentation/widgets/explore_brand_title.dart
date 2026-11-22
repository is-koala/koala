import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_shadows.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Keşfet başlığı "KOALA"; harita, liste ve yer tutucu ortak.
class ExploreBrandTitle extends StatelessWidget {
  const ExploreBrandTitle({super.key, this.floating = false});

  /// Haritada yüzüyorsa sokak adları üstünde okunsun diye gölge alır.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    return Text(
      'KOALA',
      style: context.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: context.accentColor,
        shadows: floating ? AppShadows.floatingText : null,
      ),
    );
  }
}
