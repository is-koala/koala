import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Uygulamadaki bottom sheet'lerin ortak kabuğu: zemin, üst köşeler, başlık
/// satırı ve alt güvenli alan payı.
///
/// İçeriğin kendi durumu varsa `builder` içinde bir `StatefulBuilder` ile
/// sarmalayıp bu widget'ı onun altında kur; kabuk durumla ilgilenmiyor.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  /// Sheet'i açar. Zemin saydam veriliyor ki köşe yuvarlaklığı arkasındaki
  /// varsayılan beyaz dikdörtgenle kesilmesin.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: AppRadius.sheetTop,
      ),
      padding: AppPadding.sheet.copyWith(
        bottom: context.padding.bottom + AppPadding.sheet.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: context.textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          child,
        ],
      ),
    );
  }
}
