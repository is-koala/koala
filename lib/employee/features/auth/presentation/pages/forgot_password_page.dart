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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.authService, this.onSent});

  final AuthService? authService;
  final VoidCallback? onSent;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _isSending = false;

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppToast.error(context, 'Geçerli bir e-posta adresi gir.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await _authService.forgotPassword(email);
      if (!mounted) return;
      AppToast.success(
        context,
        'Hesap varsa şifre yenileme bağlantısı e-postana gönderildi.',
      );
      final onSent = widget.onSent;
      if (onSent != null) {
        onSent();
      } else {
        context.pop();
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Unuttum')),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.authContent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'E-postana yenileme bağlantısı gönderelim',
                style: context.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.sectionSpace),
              MyTextfield(
                key: const ValueKey('forgot-password-email'),
                labelText: 'E-posta',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSizes.sectionSpace),
              MyButton(
                key: const ValueKey('forgot-password-submit'),
                onPressed: _send,
                title: 'BAĞLANTI GÖNDER',
                isLoading: _isSending,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
