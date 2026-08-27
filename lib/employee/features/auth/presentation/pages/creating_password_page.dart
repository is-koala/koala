import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/agreement_version.dart';
import 'package:koala/employee/features/auth/models/consent_decision.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_snackbar.dart';
import 'package:koala/employee/features/auth/presentation/widgets/consent_checkbox.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
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
          icon: AppIcon(AppIcons.arrowLeft, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  /// Sayfanın üç hâli var: hazırlık sürüyor, hazırlık başarısız ve form.
  Widget _body() {
    if (isPreparing) {
      return Center(
        child: CircularProgressIndicator(color: context.accentColor),
      );
    }

    final error = preparationError;
    if (error != null) {
      return _errorSection(error);
    }

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            children: [
              _formSection(),
              _consentsSection(),
              MyButton(
                onPressed: canSubmit ? onSubmit : null,
                title: isBusiness ? "DEVAM ET" : "BİTİR",
                isLoading: isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Token doğrulanamadığında ya da sözleşmeler alınamadığında gösterilir.
  Widget _errorSection(String message) {
    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(
            AppIcons.cancelCircle,
            color: AppColors.danger,
            size: AppSizes.iconLarge,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            message,
            style: context.textTheme.bodyLarge?.copyWith(
              color: context.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.sectionSpace),
          MyButton(onPressed: bootstrap, title: 'TEKRAR DENE'),
          const SizedBox(height: AppSizes.spaceSmall),
          TextButton(
            onPressed: () => context.go('/auth/register-type'),
            child: Text(
              'Kayıt ekranına dön',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sözleşme onayları. Zorunlu olanlar işaretlenmeden buton açılmıyor.
  Widget _consentsSection() {
    if (agreements.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: AppPadding.horizontalSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final agreement in agreements)
            ConsentCheckbox(
              label: agreement.type.consentLabel,
              isMandatory: agreement.mandatory,
              value: consents[agreement.id] ?? false,
              onChanged: (value) => toggleConsent(agreement.id, value),
            ),
          const SizedBox(height: AppSizes.space),
        ],
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
      icon: AppIcon(
        isVisible ? AppIcons.eyeClosed : AppIcons.eyeOpen,
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
        AppIcon(
          isOk ? AppIcons.checkCircle : AppIcons.cancelCircle,
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
