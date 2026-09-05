import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.token,
    this.authService,
    this.onCompleted,
  });

  final String token;
  final AuthService? authService;
  final VoidCallback? onCompleted;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isSaving = false;

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    final isStrong =
        password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
    if (!isStrong) {
      AppToast.error(
        context,
        'Şifre en az 8 karakter, büyük/küçük harf ve rakam içermeli.',
      );
      return;
    }
    if (password != _confirmation.text) {
      AppToast.error(context, 'Şifreler eşleşmiyor.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.resetPassword(
        resetToken: widget.token,
        newPassword: password,
      );
      if (!mounted) return;
      AppToast.success(
        context,
        'Şifren güncellendi. Şimdi giriş yapabilirsin.',
      );
      final onCompleted = widget.onCompleted;
      if (onCompleted != null) {
        onCompleted();
      } else {
        context.go('/auth/login');
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Yenile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPadding.authContent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yeni şifreni oluştur',
                style: context.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.sectionSpace),
              MyTextfield(
                labelText: 'Yeni Şifre',
                controller: _password,
                isObscureText: true,
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: 'Yeni Şifre Tekrar',
                controller: _confirmation,
                isObscureText: true,
                keyboardType: TextInputType.visiblePassword,
              ),
              const SizedBox(height: AppSizes.sectionSpace),
              MyButton(
                key: const ValueKey('reset-password-submit'),
                onPressed: _submit,
                title: 'ŞİFREYİ GÜNCELLE',
                isLoading: _isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
