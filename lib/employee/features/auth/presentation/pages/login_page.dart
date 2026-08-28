import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_divider.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_legal_footer.dart';
import 'package:koala/employee/features/auth/presentation/widgets/google_auth_button.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

part 'login_pagemodel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends LoginPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: AppIcon(AppIcons.arrowLeft, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: const AuthLegalFooter(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Container(
              padding: AppPadding.authContent,
              child: Column(
                children: [_formSection(context), _actionsSection(context)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formSection(BuildContext context) {
    return Container(
      padding: AppPadding.horizontalSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Tekrardan Hoş Geldin!",
            style: context.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.sectionSpace),
          MyTextfield(
            labelText: 'E-posta',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSizes.space),
          MyTextfield(
            labelText: 'Şifre',
            controller: passwordController,
            isObscureText: isPasswordHidden,
            showSuffixIcon: true,
            keyboardType: TextInputType.visiblePassword,
            suffixIcon: IconButton(
              icon: AppIcon(
                isPasswordHidden ? AppIcons.eyeClosed : AppIcons.eyeOpen,
                color: context.textSecondary,
              ),
              onPressed: () =>
                  setState(() => isPasswordHidden = !isPasswordHidden),
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Padding(
            padding: AppPadding.primaryLeft,
            child: GestureDetector(
              // TODO(backend): Şifre sıfırlama `/auth/forgot-password` ile
              // başlıyor ama sıfırlama bağlantısının açacağı ekran henüz yok;
              // o ekran eklenince burası bağlanacak.
              onTap: () {},
              child: Text(
                'Şifrenizi mi unuttunuz?',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
        ],
      ),
    );
  }

  Widget _actionsSection(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: AppSizes.buttonHeight,
          child: MyButton(
            onPressed: onLogin,
            title: 'GİRİŞ YAP',
            isLoading: isSubmitting,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        const AuthDivider(),
        const SizedBox(height: AppSizes.space),
        GoogleAuthButton(title: 'GOOGLE İLE GİRİŞ YAP', onPressed: () {}),
      ],
    );
  }
}
