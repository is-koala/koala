import 'package:material_ui/material_ui.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/constants/app_colors.dart';

class ChatAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackText;
  final double size;
  final double borderRadius;
  final bool isOnline;
  final double onlineDotSize;

  static const double _defaultSize = 60;
  static const double _defaultRadius = 20;
  static const double _defaultDotSize = 16;

  static const double _initialsScale = 0.3;

  static const double _dotBorder = 2;

  const ChatAvatar({
    super.key,
    this.avatarUrl,
    required this.fallbackText,
    this.size = _defaultSize,
    this.borderRadius = _defaultRadius,
    this.isOnline = false,
    this.onlineDotSize = _defaultDotSize,
  });

  /// Zemin yeşil; baş harfler temadan bağımsız beyaz.
  TextStyle get _initialsStyle => TextStyle(
    color: AppColors.onAccent,
    fontWeight: FontWeight.bold,
    fontSize: size * _initialsScale,
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.accentColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: avatarUrl != null
              ? Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (context, error, stackTrace) =>
                      Center(child: Text(fallbackText, style: _initialsStyle)),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Text(fallbackText, style: _initialsStyle),
                    );
                  },
                )
              : Center(child: Text(fallbackText, style: _initialsStyle)),
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: onlineDotSize,
              height: onlineDotSize,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.backgroundColor,
                  width: _dotBorder,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
