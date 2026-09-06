import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/job_template.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_info_notice.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/extensions/num_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'b_job_templates_pagemodel.dart';

/// İşverenin kaydettiği ilan şablonları.
///
/// Şablon buradan oluşturulmuyor: sunucu şablonu **var olan bir ilandan**
/// çıkarıyor, o yüzden giriş noktası ilan detayındaki "Şablon olarak kaydet".
/// Bu ekran listeleme ve silme için.
class BJobTemplatesPage extends StatefulWidget {
  const BJobTemplatesPage({super.key});

  @override
  State<BJobTemplatesPage> createState() => _BJobTemplatesPageState();
}

class _BJobTemplatesPageState extends BJobTemplatesPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'İlan Şablonlarım'),
      body: Consumer<BJobTemplatesProvider>(
        builder: (context, provider, child) => _body(context, provider),
      ),
    );
  }

  /// Üç durum ayrı çiziliyor: yükleniyor, hata (mesaj + Tekrar Dene) ve
  /// gerçekten boş. Sunucuya ulaşılamadığında "hiç şablonun yok" demek yanlış
  /// olurdu.
  Widget _body(BuildContext context, BJobTemplatesProvider provider) {
    if (provider.isLoading && provider.templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = provider.errorMessage;
    if (message != null && provider.templates.isEmpty) {
      return _errorState(context, provider, message);
    }

    if (provider.templates.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: () => provider.load(force: true),
      child: ListView.separated(
        padding: AppPadding.primaryAll,
        itemCount: provider.templates.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.spaceSmall),
        itemBuilder: (context, index) {
          if (index == 0) return _notice();
          return _templateCard(
            context,
            provider,
            provider.templates[index - 1],
          );
        },
      ),
    );
  }

  Widget _notice() {
    return const BInfoNotice(
      message:
          'Şablon; başlık, kategori, ücret ve gereksinimleri taşıyor. '
          'Adres ve tarih şablona dahil değil, her ilanda yeniden giriliyor.',
    );
  }

  Widget _emptyState() {
    return const EmptyState(
      icon: AppIcons.fileText,
      title: 'Henüz ilan şablonunuz yok',
      description:
          'Yayınladığınız bir ilanın detayında "Şablon olarak kaydet" '
          'diyerek aynı ilanı bir daha sıfırdan yazmaktan kurtulursunuz.',
    );
  }

  Widget _errorState(
    BuildContext context,
    BJobTemplatesProvider provider,
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

  Widget _templateCard(
    BuildContext context,
    BJobTemplatesProvider provider,
    JobTemplate template,
  ) {
    final createdAt = template.createdAt;

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: Padding(
        padding: AppPadding.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    template.templateName,
                    style: context.textTheme.titleSmall,
                  ),
                ),
                if (createdAt != null)
                  Text(
                    createdAt.toLocal().asShortDate,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              _summary(template),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
            if (template.salary != null) ...[
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                '${template.salary!.asPrice} ₺ · '
                '${template.salaryType.displayName}',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.accentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _delete(context, provider, template),
                  icon: const AppIcon(
                    AppIcons.delete,
                    size: AppSizes.iconSmall,
                  ),
                  label: const Text('Sil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
