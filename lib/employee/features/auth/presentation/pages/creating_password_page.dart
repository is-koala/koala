import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'creating_password_pagemodel.dart';

class CreatingPasswordPage extends StatefulWidget {
  const CreatingPasswordPage({super.key, this.token});
  final String? token;

  @override
  State<CreatingPasswordPage> createState() => _CreatingPasswordPageState();
}

class _CreatingPasswordPageState extends CreatingPasswordPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: context.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: AppPadding.primaryAll,
              child: Column(
                children: [
                  _formSection(),
                  MyButton(
                    onPressed: onSubmit,
                    title: isBusiness ? "DEVAM ET" : "BİTİR",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formSection() {
    return Padding(
      padding: AppPadding.horizontalSmall,
      child: Column(
        children: [
          Text(
            "Şifrenizi Oluşturalım",
            style: context.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.sectionSpace),
          MyTextfield(
            labelText: "Şifre",
            controller: passwordController,
            isObscureText: isVisiblePassword,
            showSuffixIcon: true,
            keyboardType: TextInputType.visiblePassword,
            onChanged: (value) => setState(() {}),
            suffixIcon: _visibilityToggle(
              isVisible: isVisiblePassword,
              onPressed: () =>
                  setState(() => isVisiblePassword = !isVisiblePassword),
            ),
          ),
          const SizedBox(height: AppSizes.space),
          MyTextfield(
            labelText: "Şifre Tekrar",
            controller: confirmPasswordController,
            isObscureText: isVisibleConfirmPassword,
            showSuffixIcon: true,
            keyboardType: TextInputType.visiblePassword,
            onChanged: (value) => setState(() {}),
            suffixIcon: _visibilityToggle(
              isVisible: isVisibleConfirmPassword,
              onPressed: () => setState(
                () => isVisibleConfirmPassword = !isVisibleConfirmPassword,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          if (passwordController.text.isNotEmpty) _passwordHints(),
          const SizedBox(height: AppSizes.space),
        ],
      ),
    );
  }

  Widget _visibilityToggle({
    required bool isVisible,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: HugeIcon(
        icon: isVisible
            ? HugeIcons.strokeRoundedViewOff
            : HugeIcons.strokeRoundedView,
        color: context.textSecondary,
      ),
      onPressed: onPressed,
    );
  }

  /// Şifre kutusunun altındaki durum kartı: gücü ve tekrarla eşleşmesi.
  Widget _passwordHints() {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.primaryCircular,
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hintRow(
            isOk: isPasswordStrong,
            okText: 'Güçlü şifre',
            failText: 'Şifre güçlendirilmeli',
            failColor: AppColors.warning,
          ),
          if (!isPasswordStrong) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              '• En az 8 karakter\n• Büyük harf, küçük harf ve rakam içermeli',
              style: context.textTheme.labelMedium,
            ),
          ],
          if (confirmPasswordController.text.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _hintRow(
              isOk: passwordsMatch,
              okText: 'Şifreler eşleşiyor',
              failText: 'Şifreler eşleşmiyor',
              failColor: AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }

  Widget _hintRow({
    required bool isOk,
    required String okText,
    required String failText,
    required Color failColor,
  }) {
    final color = isOk ? AppColors.success : failColor;
    return Row(
      children: [
        HugeIcon(
          icon: isOk
              ? HugeIcons.strokeRoundedCheckmarkCircle02
              : HugeIcons.strokeRoundedCancelCircle,
          color: color,
          size: AppSizes.iconMedium,
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Text(
          isOk ? okText : failText,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
