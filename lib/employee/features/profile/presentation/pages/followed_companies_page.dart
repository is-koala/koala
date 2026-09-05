import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/profile/models/followed_company.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';

/// Takip edilen şirketler.
///
/// Takibi buradan bırakmak **yok**: liste özet kayıt taşıyor, bırakma da
/// şirketin kendi ekranında zaten var. İki yerde iki ayrı doğruluk kaynağı
/// tutmaktansa satıra dokununca şirkete gidiliyor.
class FollowedCompaniesPage extends StatefulWidget {
  const FollowedCompaniesPage({super.key});

  @override
  State<FollowedCompaniesPage> createState() => _FollowedCompaniesPageState();
}

class _FollowedCompaniesPageState extends State<FollowedCompaniesPage> {
  final CompanyService _service = CompanyService();
  final ScrollController _controller = ScrollController();

  /// Listenin sonuna bu kadar kala sonraki sayfa isteniyor.
  static const double _loadMoreThreshold = 240;

  /// Logo kutusunun kenar uzunluğu.
  static const double _logoBox = 48;

  final List<FollowedCompany> _companies = [];
  int _page = 0;
  bool _isLast = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final remaining =
        _controller.position.maxScrollExtent - _controller.position.pixels;
    if (remaining <= _loadMoreThreshold) _loadMore();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final page = await _service.fetchFollowedCompanies();
      if (!mounted) return;
      setState(() {
        _companies
          ..clear()
          ..addAll(page.companies);
        _page = page.page;
        _isLast = page.last;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || _isLast) return;
    setState(() => _isLoadingMore = true);

    try {
      final page = await _service.fetchFollowedCompanies(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _companies.addAll(page.companies);
        _page = page.page;
        _isLast = page.last;
      });
    } on ApiException catch (error) {
      // Eldeki liste duruyor; kullanıcı okumaya devam edebilsin.
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Takip Ettiklerim'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading && _companies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_companies.isEmpty && _errorMessage != null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Liste açılamadı',
        description: _errorMessage!,
        action: TextButton(onPressed: _load, child: const Text('Tekrar Dene')),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _companies.isEmpty
          ? const EmptyState(
              icon: AppIcons.building,
              title: 'Takip ettiğin şirket yok',
              description:
                  'Bir şirketi takip ettiğinde yeni ilanları için '
                  'bildirim alırsın.',
            )
          : ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: AppSizes.space,
              ),
              itemCount: _companies.length + (_isLast ? 0 : 1),
              itemBuilder: (context, index) {
                if (index >= _companies.length) {
                  return const Padding(
                    padding: AppPadding.primaryAll,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return _tile(_companies[index]);
              },
            ),
    );
  }

  Widget _tile(FollowedCompany company) {
    return ListTile(
      contentPadding: AppPadding.tile,
      leading: _logo(company),
      title: Text(
        company.name,
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${company.followerCount} takipçi',
        style: context.textTheme.labelMedium?.copyWith(
          color: context.textTertiary,
        ),
      ),
      // Şirket ekranı kimliği `extra` ile alıyor.
      onTap: () => context.push('/company-detail', extra: company.companyId),
    );
  }

  Widget _logo(FollowedCompany company) {
    final logoUrl = company.logoUrl;

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: AppRadius.innerCircular,
        child: Image.network(
          logoUrl,
          width: _logoBox,
          height: _logoBox,
          fit: BoxFit.cover,
          // Logo açılmazsa satır kaybolmasın; harf kutusuna düşülüyor.
          errorBuilder: (_, _, _) => _logoFallback(company),
        ),
      );
    }

    return _logoFallback(company);
  }

  Widget _logoFallback(FollowedCompany company) {
    return Container(
      width: _logoBox,
      height: _logoBox,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.accentColor.withValues(
          alpha: AppColors.surfaceTintAlpha,
        ),
        borderRadius: AppRadius.innerCircular,
      ),
      child: AppIcon(
        AppIcons.building,
        size: AppSizes.icon,
        color: context.accentColor,
      ),
    );
  }
}
