import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class BPostsPage extends StatefulWidget {
  const BPostsPage({super.key});

  @override
  State<BPostsPage> createState() => _BPostsPageState();
}

class _BPostsPageState extends State<BPostsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Rozet ve durum kutularının zemin opaklığı.
  static const double _tintAlpha = 0.12;

  /// Başvuran satırının zemin opaklığı; rozetlerden hafif, satır bütünü
  /// kaplıyor.
  static const double _rowTintAlpha = 0.08;

  /// Geçmiş ilanlardaki çalışan avatarının ölçüsü.
  static const double _workerAvatarSize = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BJobsProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BJobsProvider>();
    final activePosts = provider.activePosts;
    final pastPosts = provider.pastPosts;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: "İş İlanlarım",
        isLarge: true,
        showBackButton: false,
      ),
      body: Column(
        children: [
          _tabBar(activePosts.length, pastPosts.length),
          const SizedBox(height: AppSizes.spaceMedium),
          Expanded(child: _content(provider, activePosts, pastPosts)),
        ],
      ),
    );
  }

  /// Üç durum ayrı çiziliyor: yükleniyor, hata (mesaj + Tekrar Dene) ve
  /// gerçekten boş. İkincisiyle üçüncüsünü aynı göstermek, sunucuya
  /// ulaşılamadığında kullanıcıya "hiç ilanın yok" demek olurdu.
  Widget _content(
    BJobsProvider provider,
    List<BJobPost> activePosts,
    List<BJobPost> pastPosts,
  ) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = provider.errorMessage;
    if (message != null && !provider.hasLoaded) return _errorState(message);

    return TabBarView(
      controller: _tabController,
      children: [
        _buildJobList(activePosts, isActive: true),
        _buildJobList(pastPosts, isActive: false),
      ],
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              AppIcons.alert,
              size: AppSizes.iconLarge,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppSizes.space),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(
              onPressed: () => context.read<BJobsProvider>().load(force: true),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBar(int activeCount, int pastCount) {
    return Container(
      margin: AppPadding.primaryHorizontal,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: context.accentColor,
          borderRadius: AppRadius.innerCircular,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: context.onAccentColor,
        unselectedLabelColor: context.textSecondary,
        labelStyle: context.textTheme.labelLarge,
        unselectedLabelStyle: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'Aktif ($activeCount)'),
          Tab(text: 'Geçmiş ($pastCount)'),
        ],
      ),
    );
  }

  Widget _buildJobList(List<BJobPost> posts, {required bool isActive}) {
    return RefreshIndicator(
      onRefresh: () => context.read<BJobsProvider>().load(force: true),
      color: context.accentColor,
      child: posts.isEmpty
          ? _emptyState(isActive: isActive)
          : ListView.separated(
              padding: AppPadding.primaryHorizontal,
              itemCount: posts.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.space),
              itemBuilder: (context, index) =>
                  _buildJobCard(posts[index], isActive: isActive),
            ),
    );
  }

  /// Boş liste de aşağı çekilip yenilenebilsin diye kaydırılabilir bir
  /// gövdenin içinde duruyor.
  Widget _emptyState({required bool isActive}) {
    return ListView(
      padding: AppPadding.primaryAll,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSizes.navBarClearance),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(
                isActive ? AppIcons.work : AppIcons.clock,
                size: AppSizes.iconHuge,
                color: context.dividerColor,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Text(
                isActive
                    ? 'Henüz aktif ilanınız yok'
                    : 'Geçmiş ilanınız bulunmuyor',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.textTertiary,
                ),
              ),
              if (isActive) ...[
                const SizedBox(height: AppSizes.spaceSmall),
                Text(
                  'Yeni ilan oluşturmak için + butonuna basın',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- Kart

  Widget _buildJobCard(BJobPost post, {required bool isActive}) {
    final job = post.job;

    return GestureDetector(
      onTap: () => context.push('/business/job-detail', extra: job.id),
      child: Container(
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          color: context.backgroundColor,
          borderRadius: AppRadius.secondaryCircular,
          border: Border.all(color: context.dividerColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.barShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(job, isActive: isActive),
            const SizedBox(height: AppSizes.space),
            Text(
              job.title,
              style: context.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              job.subtitle,
              style: context.textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSizes.space),
            _priceAndLocationRow(job),
            const SizedBox(height: AppSizes.space),
            if (isActive) _applicantsRow(post) else _workerRow(post),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader(Job job, {required bool isActive}) {
    return Row(
      children: [
        _categoryBadge(job),
        const SizedBox(width: AppSizes.spaceSmall),
        _statusBadge(isActive: isActive),
        const Spacer(),
        if (isActive) _postMenu(job),
      ],
    );
  }

  Widget _categoryBadge(Job job) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: job.category.color.withValues(alpha: _tintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            job.category.icon,
            size: AppSizes.iconSmall,
            color: job.category.color,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            job.category.displayName,
            style: context.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: job.category.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge({required bool isActive}) {
    final color = isActive ? AppColors.success : context.textTertiary;

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: _tintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        isActive ? 'Aktif' : 'Geçmiş',
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isActive ? AppColors.successStrong : context.textSecondary,
        ),
      ),
    );
  }

  Widget _postMenu(Job job) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'close') {
          _closePost(job.id);
        } else if (value == 'delete') {
          // TODO(backend): İlan silen bir uç yok; `POST /jobs/{id}/close`
          // yalnızca ilanı başvuruya kapatıyor. Menü öğesi duruyor çünkü
          // tasarımda var — uç geldiğinde buraya bağlanacak.
          AppToast.error(
            context,
            'İlan silme henüz desteklenmiyor. İlanı kapatabilirsiniz.',
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'close',
          child: Text('İlanı Kapat', style: context.textTheme.bodyMedium),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(
            'İlanı Sil',
            style: context.textTheme.bodyMedium?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ),
      ],
      icon: Icon(
        Icons.more_vert,
        color: context.textTertiary,
        size: AppSizes.iconMedium,
      ),
    );
  }

  /// İlanı kapatır ve sonucu bildirir.
  Future<void> _closePost(String jobId) async {
    final provider = context.read<BJobsProvider>();
    final closed = await provider.closePost(jobId);

    if (!mounted) return;
    if (closed) {
      AppToast.success(context, 'İlan kapatıldı');
    } else {
      AppToast.error(context, provider.errorMessage ?? 'İlan kapatılamadı');
    }
  }

  Widget _priceAndLocationRow(Job job) {
    return Row(
      children: [
        Icon(
          Icons.monetization_on_outlined,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          '₺${job.price.toStringAsFixed(0)}',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
        Icon(
          Icons.location_on_outlined,
          size: AppSizes.iconSmall,
          color: context.textTertiary,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Expanded(
          child: Text(
            job.locationLabel ?? '—',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Alt satırların ortak sarmalayıcısı: dolu ise vurgulu, boş ise nötr zemin.
  Widget _footerRow({required bool isFilled, required List<Widget> children}) {
    return Container(
      padding: AppPadding.chip,
      decoration: BoxDecoration(
        color: isFilled
            ? context.accentColor.withValues(alpha: _rowTintAlpha)
            : context.tileColor,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(children: children),
    );
  }

  /// Başvurular ilanlardan sonra ayrı bir istekle geliyor; gelmeden önce
  /// "henüz başvuru yok" yazmak yanlış bilgi olurdu.
  Widget _applicantsRow(BJobPost post) {
    final hasApplicants = post.applicants.isNotEmpty;
    final color = hasApplicants ? context.accentColor : context.textTertiary;

    return _footerRow(
      isFilled: hasApplicants,
      children: [
        AppIcon(AppIcons.userMultiple, size: AppSizes.iconSmall, color: color),
        const SizedBox(width: AppSizes.spaceSmall),
        Text(
          !post.applicantsLoaded
              ? 'Başvurular yükleniyor...'
              : hasApplicants
              ? '${post.applicants.length} başvuru'
              : 'Henüz başvuru yok',
          style: context.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const Spacer(),
        Icon(Icons.chevron_right, size: AppSizes.iconSmall, color: color),
      ],
    );
  }

  Widget _workerRow(BJobPost post) {
    final worker = post.worker;

    return _footerRow(
      isFilled: worker != null,
      children: worker != null
          ? [
              ProfileAvatar(
                imageUrl: worker.profilePictureUrl,
                size: _workerAvatarSize,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  worker.fullName,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.accentColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: AppPadding.badge,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: _tintAlpha),
                  borderRadius: AppRadius.smallCircular,
                ),
                child: Text(
                  'Kabul Edildi',
                  style: context.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.successStrong,
                  ),
                ),
              ),
            ]
          : [
              AppIcon(
                AppIcons.user,
                size: AppSizes.iconSmall,
                color: context.textTertiary,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Text(
                'Yapan kişi bilgisi yok',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: context.textTertiary,
                ),
              ),
            ],
    );
  }
}
