import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/models/b_job_post.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
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

  /// Dar alt satırdaki yükleme halkasını okunur tutan ince çizgi.
  static const double _spinnerStroke = 2;

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

  /// Kullanıcının birden çok şirketi var mı. Tek şirketli ya da bireysel
  /// işverende kartta şirket adı yazmak bilgi taşımaz; birden çok şirket adına
  /// ilan açabilen kullanıcıda hangi ilanın kimin adına olduğu görünmeli.
  bool get _showsCompanyName =>
      (context.watch<UserProvider>().user?.companies.length ?? 0) > 1;

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
    if (message != null && provider.allPosts.isEmpty) {
      return _errorState(message);
    }

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
              itemBuilder: (context, index) {
                final post = posts[index];
                // Geçmiş ilanın alt satırı işi alan kişiyi gösteriyor ve o
                // bilgi ancak başvurularda var. İstek yalnızca ekrana giren
                // satırlar için atılıyor; aktif ilanlarda hiç gerekmiyor,
                // sayı zaten ilanla geliyor.
                if (!isActive) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        !post.applicantsLoaded &&
                        !post.applicantsLoading &&
                        post.applicantsError == null) {
                      context.read<BJobsProvider>().ensureApplicants(
                        post.job.id,
                      );
                    }
                  });
                }
                return _buildJobCard(post, isActive: isActive);
              },
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
            if (job.startDateTime != null || job.headcount != null) ...[
              const SizedBox(height: AppSizes.spaceSmall),
              _scheduleAndStaffingRow(job),
            ],
            const SizedBox(height: AppSizes.space),
            if (isActive) _applicantsRow(post) else _workerRow(post),
          ],
        ),
      ),
    );
  }

  Widget _cardHeader(Job job, {required bool isActive}) {
    final companyName = job.company;

    return Row(
      children: [
        _categoryBadge(job),
        const SizedBox(width: AppSizes.spaceSmall),
        _statusBadge(job.status),
        if (_showsCompanyName) ...[
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              companyName != null && companyName.isNotEmpty
                  ? companyName
                  : 'Bireysel',
              key: ValueKey('post-company-${job.id}'),
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        if (isActive) _postMenu(job),
      ],
    );
  }

  /// İş tarihi ve kontenjan: "10.09.2026 09:00 - 17:00 · 2/3 dolu".
  ///
  /// Bitiş aynı güne düşüyorsa yalnızca saati yazılıyor; başka güne taşan
  /// işte iki tarih de tam. Kontenjan (`headcount`) sunucudan gelmediyse o
  /// parça yok — "2/— dolu" bir bilgi değil; dolunca yeşil.
  Widget _scheduleAndStaffingRow(Job job) {
    final headcount = job.headcount;
    final schedule = _scheduleLabel(job);
    final staffingLabel = headcount == null
        ? null
        : '${job.hiredCount}/$headcount dolu';
    final isFull = headcount != null && job.hiredCount >= headcount;
    final color = isFull ? AppColors.successStrong : context.textTertiary;

    return Row(
      children: [
        if (schedule != null) ...[
          AppIcon(
            AppIcons.calendar,
            size: AppSizes.iconSmall,
            color: context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceTiny),
          Expanded(
            child: Text(
              schedule,
              key: ValueKey('post-schedule-${job.id}'),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        if (staffingLabel != null) ...[
          const SizedBox(width: AppSizes.spaceSmall),
          AppIcon(AppIcons.userCheck, size: AppSizes.iconSmall, color: color),
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            staffingLabel,
            key: ValueKey('post-staffing-${job.id}'),
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  /// İlanın tarih etiketi; başlangıç yoksa `null`.
  static String? _scheduleLabel(Job job) {
    final start = job.startDateTime;
    final end = job.endDateTime;
    if (start == null) return null;
    if (end == null) return start.asShortDateTime;

    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    return sameDay
        ? '${start.asShortDateTime} - ${end.asShortTime}'
        : '${start.asShortDateTime} - ${end.asShortDateTime}';
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

  /// İlanın sunucudaki durumu. Açık ilan "Aktif" (sekmenin adı); kapalı ve
  /// iptal edilen ayrı yazılıyor — ikisi de "Geçmiş" sekmesinde ama aynı şey
  /// değil: kapalı ilan geçerliliğini koruyor, iptal edilen geçersiz.
  Widget _statusBadge(JobStatus status) {
    final (label, tint, textColor) = switch (status) {
      JobStatus.open => ('Aktif', AppColors.success, AppColors.successStrong),
      JobStatus.closed => (
        status.displayName,
        context.textTertiary,
        context.textSecondary,
      ),
      JobStatus.cancelled => (
        status.displayName,
        AppColors.danger,
        AppColors.danger,
      ),
    };

    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: _tintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _postMenu(Job job) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'close') {
          _closePost(job.id);
        } else if (value == 'cancel') {
          _cancelPost(job);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'close',
          child: Text('İlanı Kapat', style: context.textTheme.bodyMedium),
        ),
        PopupMenuItem(
          value: 'cancel',
          child: Text(
            'İlanı İptal Et',
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

  /// İlanı iptal eder.
  ///
  /// Kapatmadan farklı olduğu için önce onay soruluyor: iptal ilanı geçersiz
  /// kılıyor ve başvuranlara bildirim gidiyor.
  Future<void> _cancelPost(Job job) async {
    final confirmed = await _confirmCancel(job);
    if (confirmed != true || !mounted) return;

    final provider = context.read<BJobsProvider>();
    final cancelled = await provider.cancelPost(job.id);

    if (!mounted) return;
    if (cancelled) {
      AppToast.success(context, 'İlan iptal edildi');
    } else {
      // Devam eden bir atama varsa sunucu 409 döndürüyor; mesajı zaten
      // Türkçe geliyor ve olduğu gibi gösteriliyor.
      AppToast.error(context, provider.errorMessage ?? 'İlan iptal edilemedi');
    }
  }

  Future<bool?> _confirmCancel(Job job) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text(
          'İlanı iptal et',
          style: dialogContext.textTheme.titleMedium,
        ),
        content: Text(
          '"${job.title}" ilanı geçersiz olacak ve başvuranlara bildirim '
          'gidecek. İlan kaydı ve başvuru geçmişi silinmiyor.\n\n'
          'Yalnızca yeni başvuruyu durdurmak istiyorsanız "İlanı Kapat"ı '
          'kullanın.',
          style: dialogContext.textTheme.bodyMedium?.copyWith(
            color: dialogContext.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
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

  /// Başvuru sayısı ilan listesiyle birlikte geliyor (`applicationCount`),
  /// bu satır için ayrı bir istek atılmıyor.
  Widget _applicantsRow(BJobPost post) {
    final count = post.job.applicationCount;
    final hasApplicants = count > 0;
    final color = hasApplicants ? context.accentColor : context.textTertiary;

    return _footerRow(
      isFilled: hasApplicants,
      children: [
        AppIcon(AppIcons.userMultiple, size: AppSizes.iconSmall, color: color),
        const SizedBox(width: AppSizes.spaceSmall),
        Text(
          hasApplicants ? '$count başvuru' : 'Henüz başvuru yok',
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
    final errorMessage = post.applicantsError;
    if (errorMessage != null) {
      return _footerRow(
        isFilled: false,
        children: [
          AppIcon(
            AppIcons.alert,
            size: AppSizes.iconSmall,
            color: context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              errorMessage,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          TextButton(
            key: ValueKey('post-applicants-retry-${post.job.id}'),
            onPressed: () => context.read<BJobsProvider>().ensureApplicants(
              post.job.id,
              force: true,
            ),
            child: const Text('Tekrar Dene'),
          ),
        ],
      );
    }

    if (!post.applicantsLoaded) {
      return _footerRow(
        isFilled: false,
        children: [
          const SizedBox.square(
            dimension: AppSizes.iconSmall,
            child: CircularProgressIndicator(strokeWidth: _spinnerStroke),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Text(
            'Yapan kişi bilgisi yükleniyor',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      );
    }

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
