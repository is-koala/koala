import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/constants/password_rule.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

part 'reset_password_pagemodel.dart';

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

class _ResetPasswordPageState extends ResetPasswordPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şifremi Yenile')),
      body: SafeArea(
        child: FormPageBody(
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
