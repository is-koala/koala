import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_divider.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_legal_footer.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_snackbar.dart';
import 'package:koala/employee/features/auth/presentation/widgets/google_auth_button.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

part 'register_pagemodel.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.isBusiness});

  final bool isBusiness;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends RegisterPagemodel {
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
            child: Padding(
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
            widget.isBusiness ? "İş Hesabınızı Açalım!" : "Haydi Kayıt Olalım!",
            style: context.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.sectionSpace),
          Row(
            children: [
              Expanded(
                child: MyTextfield(
                  labelText: "Ad",
                  controller: firstNameController,
                  keyboardType: TextInputType.name,
                ),
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: MyTextfield(
                  labelText: "Soyad",
                  controller: lastNameController,
                  keyboardType: TextInputType.name,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.space),
          MyTextfield(
            labelText: 'E-posta',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSizes.spaceLarge),
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
            onPressed: onRegister,
            title: 'KAYIT OL',
            isLoading: isSubmitting,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        const AuthDivider(),
        const SizedBox(height: AppSizes.space),
        GoogleAuthButton(title: 'GOOGLE İLE KAYIT OL', onPressed: () {}),
      ],
    );
  }
}
