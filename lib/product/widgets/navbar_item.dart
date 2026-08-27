import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';

class NavItem extends StatefulWidget {
  final int index;
  final AppIconData unSelectedIcon;
  final AppIconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.index,
    required this.isSelected,
    required this.onTap,
    required this.unSelectedIcon,
    required this.selectedIcon,
  });

  @override
  State<NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<NavItem> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
        _animationController.forward();
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        _animationController.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Navbar zemini temadan bağımsız marka yeşili; üstündeki içerik
          // de öyle. Bu yüzden renkler context'ten değil AppColors'tan
          // okunuyor.
          Color backgroundColor;
          if (widget.isSelected) {
            backgroundColor = AppColors.onAccent;
          } else if (_isPressed) {
            backgroundColor = AppColors.onAccent.withValues(alpha: 0.3);
          } else {
            backgroundColor = Colors.transparent;
          }

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: AppPadding.iconButton,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor,
              ),
              child: HugeIcon(
                icon: widget.isSelected
                    ? widget.selectedIcon
                    : widget.unSelectedIcon,
                color: widget.isSelected
                    ? AppColors.primaryColor
                    : AppColors.onAccent,
                size: AppSizes.iconNav,
              ),
            ),
          );
        },
      ),
    );
  }
}
