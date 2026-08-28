import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Listesi boş olan sekmelerin ortak boş durumu.
///
/// Ölçü ve hizası tek yerde: sekmeler arasında geçerken içerik zıplamasın diye
/// ikon, başlık ve açıklama hep aynı yükseklikte duruyor. Ekranlar bunu kendi
/// başlarına kurduğunda hizalar tutmuyordu.
///
/// Kendisi kaydırılabilir ([ListView]); böylece sarmalayan
/// `RefreshIndicator` boş ekranda da çalışıyor.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final AppIconData icon;
  final String title;
  final String description;

  /// Açıklamanın altına eklenen isteğe bağlı buton (ör. "Aramayı Temizle").
  final Widget? action;

  /// İkonun kenar uzunluğu. Ekranın tek görseli olduğu için normal
  /// ikonlardan belirgin biçimde büyük.
  static const double _iconSize = 80;

  /// İçeriği dikeyde tam ortalamak yerine biraz yukarıda tutan pay; tam
  /// ortada navbar'a fazla yaklaşıyor.
  static const double _topRatio = 0.22;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: context.height * _topRatio),
        Center(
          child: Padding(
            padding: AppPadding.primaryAll,
            child: Column(
              children: [
                AppIcon(icon, size: _iconSize, color: context.dividerColor),
                const SizedBox(height: AppSizes.spaceMedium),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSizes.space),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
