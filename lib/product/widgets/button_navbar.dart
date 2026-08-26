import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Sayfanın altına sabitlenen tek butonluk çubuk.
///
/// Kendi zemini var: içeriğin altından kaydığında butonun okunur kalmasını
/// sağlıyor. Alt güvenli alan payı çalışma zamanında ekleniyor.
class ButtonNavbar extends StatelessWidget {
  const ButtonNavbar({
    super.key,
    required this.onPressed,
    required this.title,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String title;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.bottomBar.copyWith(
        bottom: context.padding.bottom + AppPadding.bottomBar.bottom,
      ),
      decoration: BoxDecoration(
        color: context.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.barShadow,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: MyButton(onPressed: onPressed, title: title, isLoading: isLoading),
    );
  }
}
