import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/talent_pool_entry.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/business/features/home/services/talent_pool_service.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:provider/provider.dart';

part 'b_talent_pool_pagemodel.dart';

/// İşverenin işaretlediği işçiler.
class BTalentPoolPage extends StatefulWidget {
  const BTalentPoolPage({super.key});

  @override
  State<BTalentPoolPage> createState() => _BTalentPoolPageState();
}

class _BTalentPoolPageState extends BTalentPoolPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Yetenek Havuzum'),
      body: Consumer<BTalentPoolProvider>(
        builder: (context, provider, child) => _body(context, provider),
      ),
    );
  }

  /// Üç durum ayrı çiziliyor: yükleniyor, hata (mesaj + Tekrar Dene) ve
  /// gerçekten boş. Sunucuya ulaşılamadığında "havuzun boş" demek yanlış
  /// olurdu.
  Widget _body(BuildContext context, BTalentPoolProvider provider) {
    if (provider.isLoading && provider.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = provider.errorMessage;
    if (message != null && provider.entries.isEmpty) {
      return _errorState(context, provider, message);
    }

    if (provider.entries.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: () => provider.load(force: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: AppPadding.primaryAll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: provider.entries.length + (provider.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.spaceSmall),
        itemBuilder: (context, index) {
          if (index >= provider.entries.length) {
            return const Padding(
              padding: AppPadding.primaryVertical,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _entryCard(context, provider, provider.entries[index]);
        },
      ),
    );
  }

  Widget _emptyState() {
    return const EmptyState(
      icon: AppIcons.bookmark,
      title: 'Yetenek havuzunuz boş',
      description:
          'Beğendiğiniz bir adayı profilinden veya başvuru kartından '
          'havuza ekleyin; bir sonraki ilanda yeniden çağırabilirsiniz.',
    );
  }

  Widget _errorState(
    BuildContext context,
    BTalentPoolProvider provider,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.alert,
              size: AppSizes.iconLarge,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(
              onPressed: () => provider.load(force: true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryCard(
    BuildContext context,
    BTalentPoolProvider provider,
    TalentPoolEntry entry,
  ) {
    final createdAt = entry.createdAt;
    final note = entry.note;

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: () =>
            context.push('/business/user-profile', extra: entry.worker.id),
        child: Padding(
          padding: AppPadding.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileAvatar(
                imageUrl: entry.worker.profilePictureUrl,
                size: BTalentPoolPagemodel._avatarSize,
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.worker.fullName,
                      style: context.textTheme.titleSmall,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: AppSizes.spaceTiny),
                      Text(
                        createdAt.toLocal().asShortDate,
                        style: context.textTheme.labelSmall?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                    if (note != null && note.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.spaceTiny),
                      Text(
                        note,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notu düzenle',
                onPressed: () => _editNote(context, provider, entry),
                icon: AppIcon(
                  AppIcons.edit,
                  size: AppSizes.iconSmall,
                  color: context.textSecondary,
                ),
              ),
              IconButton(
                tooltip: 'Havuzdan çıkar',
                onPressed: () => _remove(context, provider, entry),
                icon: AppIcon(
                  AppIcons.delete,
                  size: AppSizes.iconSmall,
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
