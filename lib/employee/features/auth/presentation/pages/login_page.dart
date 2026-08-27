import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_divider.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_legal_footer.dart';
import 'package:koala/employee/features/auth/presentation/widgets/google_auth_button.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.textPrimary,
          ),
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
          MyTextfield(labelText: 'E-posta'),
          const SizedBox(height: AppSizes.space),
          MyTextfield(labelText: 'Şifre'),
          const SizedBox(height: AppSizes.spaceSmall),
          Padding(
            padding: AppPadding.primaryLeft,
            child: GestureDetector(
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
            onPressed: () => _loginAs(context, 'employee', '/explore'),
            title: 'GİRİŞ YAP',
          ),
        ),
        const SizedBox(height: AppSizes.space),
        const AuthDivider(),
        const SizedBox(height: AppSizes.space),
        GoogleAuthButton(title: 'GOOGLE İLE GİRİŞ YAP', onPressed: () {}),
        const SizedBox(height: AppSizes.space),
        // TODO(backend): Gerçek giriş akışı bağlanınca kaldırılacak.
        TextButton(
          onPressed: () => _loginAs(context, 'business', '/business/home'),
          child: Text(
            'İş Veren Arayüzünü Gör (Demo)',
            style: context.textTheme.labelLarge?.copyWith(
              color: context.accentColor,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _loginAs(
    BuildContext context,
    String userType,
    String destination,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_type', userType);

    if (context.mounted) {
      context.go(destination);
    }
  }
}
