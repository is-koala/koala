import 'package:flutter/material.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Keşif sekmesinin app bar başlığı: marka renginde kalın "KOALA".
///
/// Harita, liste ve haritasız yer tutucu aynı başlığı çiziyor; üç kopya
/// yerine tek widget, görünüm sekmeler arasında kaymasın diye.
class ExploreBrandTitle extends StatelessWidget {
  const ExploreBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'KOALA',
      style: context.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        color: context.accentColor,
      ),
    );
  }
}
