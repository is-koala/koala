import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/user_session.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Oturumun cihaz türünü gösteren vurgu renkli ikon karosu.
///
/// Oturum listesi satırı ve oturum ayrıntısı başlığı aynı karoyu çiziyor.
class SessionDeviceIcon extends StatelessWidget {
  const SessionDeviceIcon(this.type, {super.key});

  final SessionDeviceType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.iconTile,
      height: AppSizes.iconTile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(
          alpha: AppColors.surfaceTintAlpha,
        ),
        borderRadius: AppRadius.innerCircular,
      ),
      child: AppIcon(
        type.icon,
        size: AppSizes.icon,
        color: context.accentColor,
      ),
    );
  }
}
