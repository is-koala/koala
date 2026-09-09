import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Kayıt tamamlandıktan sonra işverenin hangi modelle ilerleyeceğini seçer.
///
/// Bireysel işveren kişisel ilan uçlarını kullanır; şirket seçen kullanıcı
/// gerçek şirket oluşturma formunu tamamlamadan işveren ana sayfasına gitmez.
class EmployerTypePage extends StatelessWidget {
  const EmployerTypePage({
    super.key,
    this.onIndividualSelected,
    this.onCompanySelected,
  });

  final VoidCallback? onIndividualSelected;
  final VoidCallback? onCompanySelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.authContent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nasıl iş vermek istersin?',
                style: context.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Text(
                'Kendi adına ilan verebilir veya şirket profilini '
                'oluşturabilirsin.',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const Spacer(),
              MyButton(
                key: const ValueKey('employer-type-individual'),
                title: 'Bireysel İşveren',
                isReversed: true,
                onPressed:
                    onIndividualSelected ?? () => context.go('/business/home'),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyButton(
                key: const ValueKey('employer-type-company'),
                title: 'Şirket Olarak Devam Et',
                onPressed:
                    onCompanySelected ??
                    () => context.go(RegistrationRoutes.companyInformations),
              ),
              const SizedBox(height: AppSizes.spaceLarge),
            ],
          ),
        ),
      ),
    );
  }
}
