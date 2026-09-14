import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

part 'forgot_password_pagemodel.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.authService, this.onSent});

  final AuthService? authService;
  final VoidCallback? onSent;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ForgotPasswordPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Unuttum')),
      body: SafeArea(
        child: FormPageBody(
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
