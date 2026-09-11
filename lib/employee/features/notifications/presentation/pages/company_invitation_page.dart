import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/company_contact_invitation.dart';
import 'package:koala/business/features/home/services/company_contact_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:provider/provider.dart';

part 'company_invitation_pagemodel.dart';

/// Davet edilen kişinin gördüğü kabul / red ekranı.
class CompanyInvitationPage extends StatefulWidget {
  const CompanyInvitationPage({super.key, required this.invitationId});

  final String invitationId;

  @override
  State<CompanyInvitationPage> createState() => _CompanyInvitationPageState();
}

class _CompanyInvitationPageState extends CompanyInvitationPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Şirket Daveti'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading && _invitation == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = _errorMessage;
    if (message != null && _invitation == null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Davet açılamadı',
        description: message,
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    final invitation = _invitation;
    if (invitation == null) {
      return const EmptyState(
        icon: AppIcons.alert,
        title: 'Davet bulunamadı',
        description: 'Davet bulunamadı ya da size ait değil.',
      );
    }

    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            invitation.companyName,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.space),
          Text(
            '${invitation.invitedBy.fullName} sizi '
            '${invitation.role.displayName.toLowerCase()} olarak davet etti.',
            style: context.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          _statusBox(invitation),
          const Spacer(),
          if (invitation.isPending) ...[
            MyButton(
              onPressed: _isBusy ? null : () => _answer(accepted: true),
              title: 'Kabul Et',
              isLoading: _isBusy,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            MyButton(
              onPressed: _isBusy ? null : () => _answer(accepted: false),
              title: 'Reddet',
              isReversed: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBox(CompanyContactInvitation invitation) {
    if (invitation.isPending) return const SizedBox.shrink();

    final rejected =
        invitation.status == CompanyContactInvitationStatus.rejected;
    final color = rejected ? AppColors.danger : AppColors.success;

    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        children: [
          AppIcon(
            rejected ? AppIcons.cancelCircle : AppIcons.checkCircle,
            color: color,
            size: AppSizes.icon,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Text(
              rejected ? 'Bu daveti reddettiniz.' : 'Bu daveti kabul ettiniz.',
              style: context.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
