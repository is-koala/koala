import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/company_contact.dart';
import 'package:koala/business/features/home/services/company_contact_service.dart';
import 'package:koala/employee/features/auth/models/company_membership.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/option_sheet.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

part 'b_company_contacts_pagemodel.dart';

/// Şirket yetkilileri listesi ve davet yönetimi.
class BCompanyContactsPage extends StatefulWidget {
  const BCompanyContactsPage({super.key, this.service});

  @visibleForTesting
  final CompanyContactService? service;

  @override
  State<BCompanyContactsPage> createState() => _BCompanyContactsPageState();
}

class _BCompanyContactsPageState extends BCompanyContactsPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: 'Şirket Yetkilileri',
        actions: [
          if (canManage)
            IconButton(
              tooltip: 'Yetkili Davet Et',
              icon: AppIcon(
                AppIcons.plus,
                color: context.textPrimary,
                size: AppSizes.icon,
              ),
              onPressed: _invite,
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading && _contacts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = _errorMessage;
    if (message != null && _contacts.isEmpty) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Yetkililer alınamadı',
        description: message,
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return const EmptyState(
        icon: AppIcons.userMultiple,
        title: 'Henüz yetkili yok',
        description: 'Şirkete başka bir Koala kullanıcısını davet edin.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: AppPadding.primaryAll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _contacts.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.spaceSmall),
        itemBuilder: (context, index) => _contactCard(_contacts[index]),
      ),
    );
  }

  Widget _contactCard(CompanyContact contact) {
    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: Padding(
        padding: AppPadding.card,
        child: Row(
          children: [
            ProfileAvatar(
              imageUrl: contact.user.profilePictureUrl,
              size: BCompanyContactsPagemodel._avatarSize,
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.user.fullName,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.smallGap),
                  _roleBadge(contact.role),
                ],
              ),
            ),
            if (canManage)
              IconButton(
                tooltip: 'Yetkiliyi çıkar',
                onPressed: () => _remove(contact),
                icon: AppIcon(
                  AppIcons.close,
                  color: AppColors.danger,
                  size: AppSizes.iconMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(CompanyContactRole role) {
    final color = role == CompanyContactRole.admin
        ? context.accentColor
        : context.textTertiary;

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        role.displayName,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
