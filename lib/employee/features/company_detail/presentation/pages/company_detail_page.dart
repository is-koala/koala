import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/product/widgets/gallery_strip.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_list_tile.dart';
import 'package:url_launcher/url_launcher.dart';

part 'company_detail_pagemodel.dart';

class CompanyDetailPage extends StatefulWidget {
  /// Ekran kaydı kendisi çekiyor: ilan, iş ya da sohbetten gelinebiliyor ve
  /// elde çoğu zaman yalnız kimlik var.
  final String companyId;
  final CompanyService? companyService;
  final JobService? jobService;

  const CompanyDetailPage({
    super.key,
    required this.companyId,
    this.companyService,
    this.jobService,
  });

  static const double appBarExpandedHeight = 230;

  @override
  State<CompanyDetailPage> createState() => _CompanyDetailPageState();
}

class _CompanyDetailPageState extends CompanyDetailPagemodel {
  static const double _logoSize = 80;

  /// Çalışan önce işverene bakıyor; ilanlar sayfayı aşağı itmesin.
  static const int _previewJobCount = 3;

  static const double _onCoverMuted = 0.9;

  @override
  Widget build(BuildContext context) {
    final loaded = company;

    if (loaded == null) {
      return Scaffold(
        backgroundColor: context.backgroundColor,
        appBar: MyAppbar(title: 'Şirket'),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorState(errorMessage ?? 'Şirket bulunamadı'),
      );
    }

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: RefreshIndicator(
        onRefresh: load,
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            appBar(context, loaded),
            SliverToBoxAdapter(child: _content(loaded)),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(onPressed: load, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ İçerik

  /// Sıra çalışanın sorusunu izliyor ("bu işveren güvenilir mi"): önce özet,
  /// kim olduğu ve iletişim, en sonda ilanlar.
  Widget _content(Company company) {
    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(company),
          const SizedBox(height: AppSizes.spaceMedium),
          _followButton(company),
          if (company.description != null) ...[
            const SizedBox(height: AppSizes.spaceLarge),
            _buildSectionTitle('Hakkında'),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              company.description!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ],
          if (company.images.isNotEmpty) ...[
            const SizedBox(height: AppSizes.spaceLarge),
            _buildSectionTitle('Galeri'),
            const SizedBox(height: AppSizes.space),
            // Galerisiz şirkette bölüm yok; boş başlık eksik sayfa gibi okunur.
            GalleryStrip(images: company.images),
          ],
          ..._contactSection(company),
          if (_contactSection(company).isEmpty)
            const SizedBox(height: AppSizes.spaceLarge),
          _buildJobsSection(),
          const SizedBox(height: AppSizes.sectionSpace),
        ],
      ),
    );
  }

  /// Açık ilan ve takipçi; ilan sayısı istek dönene kadar tire.
  Widget _summaryRow(Company company) {
    return FutureBuilder<List<Job>>(
      future: companyJobsFuture,
      builder: (context, snapshot) {
        final jobCount = snapshot.hasData ? '${snapshot.data!.length}' : '–';
        return Row(
          children: [
            Expanded(child: _summaryItem(jobCount, 'Açık ilan')),
            _summaryDivider(),
            Expanded(
              child: _summaryItem('${company.followerCount}', 'Takipçi'),
            ),
          ],
        );
      },
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: context.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.smallGap),
        Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _summaryDivider() => SizedBox(
    height: AppSizes.spaceXLarge,
    child: VerticalDivider(
      width: AppSizes.divider,
      color: context.dividerColor,
    ),
  );

  /// Asıl karar başka sayfada olduğu için çerçeveli, dolgulu değil.
  Widget _followButton(Company company) {
    final following = company.isFollowing;
    return SizedBox(
      width: double.infinity,
      height: AppSizes.actionButtonHeight,
      child: OutlinedButton.icon(
        onPressed: isTogglingFollow ? null : toggleFollow,
        icon: AppIcon(
          following ? AppIcons.userCheck : AppIcons.userAdd,
          size: AppSizes.iconSmall,
          color: context.textPrimary,
        ),
        label: Text(following ? 'Takip Ediliyor' : 'Takip Et'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.textPrimary,
          backgroundColor: following ? context.tileColor : null,
          textStyle: context.textTheme.labelLarge,
          side: BorderSide(color: context.dividerColor),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.innerCircular),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ Kapak

  SliverAppBar appBar(BuildContext context, Company company) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: CompanyDetailPage.appBarExpandedHeight,
      backgroundColor: context.accentColor,
      leading: IconButton(
        icon: const AppIcon(AppIcons.arrowLeft, color: AppColors.onAccent),
        onPressed: () => context.pop(),
      ),
      centerTitle: false,
      title: ValueListenableBuilder<double>(
        valueListenable: titleOpacity,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Text(
          company.name,
          style: context.textTheme.titleMedium?.copyWith(
            color: AppColors.onAccent,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.spaceMedium,
              0,
              AppSizes.spaceMedium,
              AppSizes.spaceMedium,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                _logo(company),
                const SizedBox(height: AppSizes.space),
                Text(
                  company.name,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onAccent,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_coverSubtitle(company) case final subtitle?) ...[
                  const SizedBox(height: AppSizes.smallGap),
                  Text(
                    subtitle,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: AppColors.onAccent.withValues(
                        alpha: _onCoverMuted,
                      ),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSizes.spaceSmall),
                _trustLine(company),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _coverSubtitle(Company company) {
    final parts = [?company.type?.displayName, ?company.address?.shortLabel];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// "Bu işveren gerçek mi"nin cevabı; rozet değil ikon ve düz metin.
  Widget _trustLine(Company company) {
    final approved = company.isApproved;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(
          approved ? AppIcons.verified : AppIcons.alert,
          filled: approved,
          size: AppSizes.iconSmall,
          color: AppColors.onAccent,
        ),
        const SizedBox(width: AppSizes.spaceTiny),
        Text(
          approved ? 'Onaylı işveren' : 'Henüz onaylanmadı',
          style: context.textTheme.labelMedium?.copyWith(
            color: AppColors.onAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _logo(Company company) {
    final placeholder = AppIcon(
      AppIcons.building,
      size: AppSizes.iconLarge,
      color: context.textTertiary,
    );

    return Container(
      width: _logoSize,
      height: _logoSize,
      decoration: BoxDecoration(
        color: context.backgroundColor,
        borderRadius: AppRadius.secondaryCircular,
        boxShadow: [
          BoxShadow(
            color: AppColors.mapShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: company.logoUrl != null
          ? ClipRRect(
              borderRadius: AppRadius.secondaryCircular,
              child: Image.network(
                company.logoUrl!,
                width: _logoSize,
                height: _logoSize,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => placeholder,
              ),
            )
          : placeholder,
    );
  }

  // ------------------------------------------------------------------ İlanlar

  /// Açık ilanlar, listedeki kartın aynısıyla; ilk [_previewJobCount], fazlası
  /// tek dokunuşla.
  Widget _buildJobsSection() {
    return FutureBuilder<List<Job>>(
      future: companyJobsFuture,
      builder: (context, snapshot) {
        final title = _buildSectionTitle('Açık ilanlar');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              _centered(CircularProgressIndicator(color: context.accentColor)),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: AppSizes.space),
              _mutedText('İlanlar yüklenemedi. Aşağı çekip yenile.'),
            ],
          );
        }

        final jobs = snapshot.data ?? const <Job>[];
        if (jobs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: AppSizes.space),
              _mutedText('Şu an açık ilanı yok.'),
            ],
          );
        }

        final visible = showAllJobs ? jobs : jobs.take(_previewJobCount);
        final hidden = jobs.length - _previewJobCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: AppSizes.space),
            for (final job in visible) JobCard(job: job),
            if (hidden > 0)
              Center(
                child: TextButton(
                  key: const ValueKey('company-jobs-toggle'),
                  onPressed: toggleShowAllJobs,
                  style: TextButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    textStyle: context.textTheme.labelLarge,
                  ),
                  child: Text(
                    showAllJobs
                        ? 'Daha az göster'
                        : 'Tüm ilanları göster (${jobs.length})',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _centered(Widget child) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.spaceXLarge),
      child: child,
    ),
  );

  Widget _mutedText(String text) => Text(
    text,
    style: context.textTheme.bodyMedium?.copyWith(color: context.textSecondary),
  );

  // --------------------------------------------------------------- İletişim

  /// İletişim tek kartta ([MyListGroup]); her satır ilgili uygulamayı açtığı
  /// için ok dışarı bakıyor. Hiçbiri yoksa bölüm yok.
  List<Widget> _contactSection(Company company) {
    final email = company.email;
    final phone = company.phoneNumber;
    final website = company.website;
    final address = company.address;
    final position = address?.position;
    final addressText = address?.displayAddress ?? address?.shortLabel;

    final rows = <Widget>[
      if (email != null)
        MyListTile(
          icon: AppIcons.mail,
          title: email,
          opensExternally: true,
          onTap: () => openExternal(Uri(scheme: 'mailto', path: email)),
        ),
      if (phone != null)
        MyListTile(
          icon: AppIcons.call,
          title: _displayPhone(phone),
          opensExternally: true,
          onTap: () => openExternal(Uri(scheme: 'tel', path: phone)),
        ),
      if (website != null)
        MyListTile(
          icon: AppIcons.globe,
          title: _displayWebsite(website),
          opensExternally: true,
          onTap: () => openExternal(Uri.parse(_websiteUrl(website))),
        ),
      if (addressText != null)
        MyListTile(
          icon: AppIcons.location,
          title: addressText,
          opensExternally: true,
          onTap: position == null
              ? null
              : () => openExternal(
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': '${position.latitude},${position.longitude}',
                  }),
                ),
        ),
    ];
    if (rows.isEmpty) return const [];

    return [
      const SizedBox(height: AppSizes.spaceLarge),
      _buildSectionTitle('İletişim'),
      const SizedBox(height: AppSizes.space),
      MyListGroup(children: rows),
    ];
  }

  /// `+905551234567` → `0555 123 45 67`; Türk numarası değilse olduğu gibi.
  static String _displayPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('90') && digits.length == 12
        ? digits.substring(2)
        : digits.startsWith('0') && digits.length == 11
        ? digits.substring(1)
        : null;
    if (national == null) return phone;
    return '0${national.substring(0, 3)} ${national.substring(3, 6)} '
        '${national.substring(6, 8)} ${national.substring(8)}';
  }

  static String _displayWebsite(String website) => website
      .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
      .replaceFirst(RegExp(r'^www\.', caseSensitive: false), '')
      .replaceFirst(RegExp(r'/$'), '');

  static String _websiteUrl(String website) =>
      RegExp(r'^https?://', caseSensitive: false).hasMatch(website)
      ? website
      : 'https://$website';

  // ------------------------------------------------------------ Ortak parçalar

  Widget _buildSectionTitle(String title) =>
      Text(title, style: context.textTheme.titleMedium);
}
