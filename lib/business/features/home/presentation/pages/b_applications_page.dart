import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/models/received_application.dart';
import 'package:koala/business/features/home/presentation/providers/b_application_inbox_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_received_application_card.dart';
import 'package:koala/business/features/home/services/received_application_service.dart';
import 'package:koala/employee/features/auth/models/company_membership.dart';
import 'package:koala/employee/features/jobs/models/job_application.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/filter_pill.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/option_sheet.dart';
import 'package:provider/provider.dart';

part 'b_applications_pagemodel.dart';

/// İşverenin ilanlar arası başvuru gelen kutusu (is-koala/koala#213).
///
/// `GET /users/me/received-applications`: sahibi olunan bireysel ilanlar ve
/// yetkilisi olunan şirketlerin ilanları, tek sayfalı liste. Kapsamı sunucu
/// kuruyor; bu ekran yalnız süzüyor (durum, şirket, ilan) ve **karar vermiyor**
/// — karta dokunmak ilanın kabul/ret ekranını açıyor.
class BApplicationsPage extends StatefulWidget {
  const BApplicationsPage({super.key, this.service});

  /// Testler için; verilmezse üretimdeki tekil servis.
  final ReceivedApplicationService? service;

  @override
  State<BApplicationsPage> createState() => _BApplicationsPageState();
}

class _BApplicationsPageState extends BApplicationsPagemodel {
  @override
  Widget build(BuildContext context) {
    // Yalnız onaylı şirketler çip oluyor: onaysız bir şirketin ilan açması
    // mümkün değil, süzecek bir şey de yok.
    final companies = context.select<UserProvider, List<CompanyMembership>>(
      (provider) => [
        for (final company in provider.user?.companies ?? const [])
          if (company.approved) company,
      ],
    );
    final ownPosts = context.watch<BJobsProvider>().allPosts;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Başvurular'),
      body: ListenableBuilder(
        listenable: _inbox,
        builder: (context, _) => Column(
          children: [
            _filters(context, companies, ownPosts),
            Expanded(child: _content(context)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Süzgeç

  /// Durum çipleri her zaman; şirket çipleri kullanıcının şirket üyeliği
  /// varsa (bireysel ilanlar "Tüm şirketler"in içinde kalır); ilan çipi
  /// seçilecek bir ilan biliniyorsa ya da bir ilan seçiliyse.
  Widget _filters(
    BuildContext context,
    List<CompanyMembership> companies,
    List<BJobPost> ownPosts,
  ) {
    final showJobPill = _inbox.jobId != null || _knownJobs(ownPosts).isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSizes.spaceSmall,
        bottom: AppSizes.spaceSmall,
      ),
      child: Column(
        children: [
          _pillRow([
            FilterPill(
              key: const ValueKey('inbox-status-all'),
              label: 'Tümü',
              isSelected: _inbox.status == null,
              onTap: () => _inbox.setStatus(null),
            ),
            for (final status in BApplicationsPagemodel._filterStatuses)
              FilterPill(
                key: ValueKey('inbox-status-${status.code}'),
                label: status.inboxFilterLabel,
                isSelected: _inbox.status == status,
                onTap: () => _inbox.setStatus(status),
              ),
          ]),
          if (companies.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _pillRow([
              FilterPill(
                key: const ValueKey('inbox-company-all'),
                label: 'Tüm şirketler',
                isSelected: _inbox.companyId == null,
                onTap: () => _inbox.setCompany(null),
              ),
              for (final company in companies)
                FilterPill(
                  key: ValueKey('inbox-company-${company.companyId}'),
                  label: company.companyName,
                  isSelected: _inbox.companyId == company.companyId,
                  onTap: () => _inbox.setCompany(company.companyId),
                ),
            ]),
          ],
          if (showJobPill) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _pillRow([
              FilterPill(
                key: const ValueKey('inbox-job-pill'),
                label: _inbox.jobId == null
                    ? 'İlana göre'
                    : 'İlan: ${_inbox.jobTitle}',
                isSelected: _inbox.jobId != null,
                onTap: () => _pickJob(ownPosts),
                onRemove: _inbox.jobId == null ? null : _inbox.clearJob,
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _pillRow(List<Widget> pills) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: AppPadding.primaryHorizontal,
      child: Row(
        children: [
          for (var index = 0; index < pills.length; index++) ...[
            if (index > 0) const SizedBox(width: AppSizes.spaceSmall),
            pills[index],
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ İçerik

  /// Dört durum ayrı çiziliyor: yükleniyor, hata (mesaj + Tekrar Dene), süzgeçli
  /// ya da süzgeçsiz boş, ve liste. Sunucuya ulaşılamadığında "başvuru yok"
  /// demek yanlış olurdu.
  Widget _content(BuildContext context) {
    if (_inbox.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = _inbox.errorMessage;
    final items = _inbox.items;
    if (message != null && items.isEmpty) {
      return _refreshable(_errorState(context, message));
    }
    if (items.isEmpty) return _refreshable(_emptyState());

    return _refreshable(
      ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppPadding.primary,
          AppSizes.spaceSmall,
          AppPadding.primary,
          AppPadding.primary,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length + (_hasFooter ? 1 : 0),
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.spaceSmall),
        itemBuilder: (context, index) {
          if (index >= items.length) return _footer(context);
          final application = items[index];
          return BReceivedApplicationCard(
            key: ValueKey('application-${application.id}'),
            application: application,
            onOpen: () => _openReview(application),
            onOpenProfile: () => _openProfile(application),
          );
        },
      ),
    );
  }

  Widget _refreshable(Widget child) {
    return RefreshIndicator(onRefresh: _onRefresh, child: child);
  }

  /// Listenin sonu: sonraki sayfa yükleniyor ya da yüklenemedi.
  bool get _hasFooter => _inbox.isLoadingMore || _inbox.loadMoreError != null;

  Widget _footer(BuildContext context) {
    final error = _inbox.loadMoreError;
    if (error == null) {
      return const Padding(
        padding: AppPadding.primaryVertical,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      children: [
        Text(
          error,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        OutlinedButton(
          key: const ValueKey('inbox-load-more-retry'),
          onPressed: _inbox.retryLoadMore,
          child: const Text('Tekrar Dene'),
        ),
      ],
    );
  }

  Widget _emptyState() {
    if (_inbox.isFiltered) {
      return EmptyState(
        icon: AppIcons.userMultiple,
        title: 'Bu süzgeçte başvuru yok',
        description:
            'Başka bir durum, şirket ya da ilan seçerek diğer başvurulara '
            'bakabilirsiniz.',
        action: OutlinedButton(
          key: const ValueKey('inbox-clear-filters'),
          onPressed: _inbox.clearFilters,
          child: const Text('Süzgeçleri Temizle'),
        ),
      );
    }

    return const EmptyState(
      icon: AppIcons.userMultiple,
      title: 'Henüz başvuru yok',
      description:
          'Açtığınız bireysel ilanlara ve yetkilisi olduğunuz şirketlerin '
          'ilanlarına gelen başvurular burada görünecek.',
    );
  }

  Widget _errorState(BuildContext context, String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppPadding.primaryAll,
      children: [
        const SizedBox(height: AppSizes.spaceHuge),
        Center(
          child: AppIcon(
            AppIcons.alert,
            size: AppSizes.iconLarge,
            color: context.textTertiary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Center(
          child: OutlinedButton(
            key: const ValueKey('inbox-retry'),
            onPressed: _inbox.load,
            child: const Text('Tekrar Dene'),
          ),
        ),
      ],
    );
  }
}
