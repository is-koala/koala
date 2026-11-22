import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Boş listelerin ortak görünümü; ölçü tek yerde ki sekme değişince içerik
/// zıplamasın. Kendisi kaydırılabilir, böylece `RefreshIndicator` boşken de
/// çalışıyor.
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

  final Widget? action;

  static const double _iconSize = 80;

  /// Tam ortada navbar'a fazla yaklaşıyor.
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
