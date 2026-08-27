import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Auth akışındaki bilgilendirme ve hata mesajlarını gösteren ortak snackbar.
///
/// Giriş, kayıt ve şifre ekranlarının üçü de aynı mesaj kutusunu kullandığı
/// için tek yerde toplandı.
class AuthSnackbar {
  const AuthSnackbar._();

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(
              color: isError ? AppColors.onAccent : AppColors.onLightSurface,
            ),
          ),
          backgroundColor: isError ? AppColors.danger : AppColors.primarySoft,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
