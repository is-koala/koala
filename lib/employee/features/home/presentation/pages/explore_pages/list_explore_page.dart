import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/job_search_provider.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

part 'list_explore_pagemodel.dart';

class ListExplorePage extends StatefulWidget {
  const ListExplorePage({super.key});

  @override
  State<ListExplorePage> createState() => _ListExplorePageState();
}

class _ListExplorePageState extends ListExplorePagemodel {
  /// Arama kutusunu da taşıyan appbar'ın yüksekliği. Açılıp kapanmıyor,
  /// bu yüzden expanded ve collapsed değerleri aynı.
  static const double _appBarHeight = 124;

  /// Arama kutusunun kapalıyken genişliği: yalnızca arama ikonu kadar.
  static const double _collapsedSearchWidth = 50;

  /// Aktif filtre butonunun zemin opaklığı.
  static const double _activeFilterAlpha = 0.15;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final search = context.watch<JobSearchProvider>();
    final jobs = _visibleJobs(search.jobs);

    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        // Kartlar zeminden yükselsin diye sayfa geri çekilmiş bir ton.
        backgroundColor: context.recessedColor,
        extendBody: true,
        extendBodyBehindAppBar: false,
        body: RefreshIndicator(
          onRefresh: () => _search.load(silent: true),
          child: CustomScrollView(
            controller: _scrollController,
            // Liste kısayken de aşağı çekilebilsin: RefreshIndicator'ın
            // çalışması buna bağlı.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              appBar(context),
              const SliverToBoxAdapter(child: SizedBox(height: AppSizes.space)),
              filters(),
              if (_searchController.text.isNotEmpty)
                SliverToBoxAdapter(child: _searchSummary(search)),
              SliverToBoxAdapter(child: _listHeader()),
              if (search.isLoading && jobs.isEmpty)
                SliverToBoxAdapter(child: _centered(_loadingIndicator()))
              else if (jobs.isEmpty)
                SliverToBoxAdapter(child: _centered(_emptyState(search)))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= jobs.length) return _loadMoreIndicator();
                    final job = jobs[index];
                    return JobCard(job: job, distance: _getDistance(job));
                  }, childCount: jobs.length + (search.hasMore ? 1 : 0)),
                ),
              if (search.errorMessage != null && jobs.isNotEmpty)
                SliverToBoxAdapter(child: _errorStrip(search.errorMessage!)),
              const SliverToBoxAdapter(
                child: SizedBox(height: AppSizes.navBarClearance),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- Bölümler

  Widget _centered(Widget child) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSizes.spaceXLarge),
      child: child,
    ),
  );

  Widget _loadingIndicator() =>
      Center(child: CircularProgressIndicator(color: context.accentColor));

  Widget _loadMoreIndicator() => Padding(
    padding: AppPadding.primaryAll,
    child: Center(child: CircularProgressIndicator(color: context.accentColor)),
  );

  Widget _listHeader() {
    return Padding(
      padding: AppPadding.primaryHorizontal,
      child: Text('Yakındaki İşler', style: context.textTheme.titleMedium),
    );
  }

  /// Sayfa eklenemediğinde listenin altına düşen şerit.
  ///
  /// Liste ekranda kalıyor — hata yüzünden eldeki ilanları silmek kullanıcıyı
  /// kazandığı yerden geri atardı; `debugPrint` ise kullanıcıya hiçbir şey
  /// söylemiyor.
  Widget _errorStrip(String message) {
    return Padding(
      padding: AppPadding.primaryAll,
      child: Row(
        children: [
          AppIcon(
            AppIcons.alert,
            size: AppSizes.iconSmall,
            color: context.textSecondary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _search.loadMore(),
            child: Text(
              'Tekrar Dene',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchSummary(JobSearchProvider search) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppPadding.primary,
        AppSizes.spaceMedium,
        AppPadding.primary,
        0,
      ),
      child: Row(
        children: [
          Text(
            '"${_searchController.text}" için ${search.totalElements} sonuç',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _clearSearch,
            child: Text(
              'Temizle',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Boş liste üç ayrı sebepten olabiliyor ve üçü farklı çıkış istiyor.
  ///
  /// Süzgeç sunucuya taşındıktan sonra da ayrım korunuyor: ayrımı listenin
  /// kendisi değil, **uygulanan sorgu** anlatıyor.
  String _emptyMessage(JobSearchProvider search) {
    final query = search.query;
    if (search.errorMessage != null) return search.errorMessage!;
    if (query.hasQuery) return '"${query.query}" ile eşleşen iş bulunamadı';
    if (query.hasFilters) return 'Bu filtreye uygun iş bulunamadı';
    return 'Yakınında henüz ilan yok';
  }

  Widget _emptyState(JobSearchProvider search) {
    final query = search.query;
    final hasSearch = query.hasQuery;

    return Column(
      children: [
        AppIcon(
          search.errorMessage != null ? AppIcons.alert : AppIcons.searchList,
          size: AppSizes.iconHuge,
          color: context.textTertiary,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Text(
          _emptyMessage(search),
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.textSecondary,
          ),
        ),
        if (search.errorMessage != null) ...[
          const SizedBox(height: AppSizes.space),
          TextButton(
            onPressed: () => _search.load(),
            child: Text(
              'Tekrar Dene',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.accentColor,
              ),
            ),
          ),
        ] else if (hasSearch) ...[
          const SizedBox(height: AppSizes.space),
          TextButton(
            onPressed: _clearSearch,
            child: Text(
              'Aramayı Temizle',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.accentColor,
              ),
            ),
          ),
        ] else if (query.hasFilters) ...[
          const SizedBox(height: AppSizes.space),
          TextButton(
            onPressed: _clearFilters,
            child: Text(
              'Süzgeçleri Temizle',
              style: context.textTheme.labelLarge?.copyWith(
                color: context.accentColor,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------- Filtre çubuğu

  SliverToBoxAdapter filters() {
    return SliverToBoxAdapter(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppPadding.primary,
          vertical: AppSizes.spaceSmall,
        ),
        decoration: BoxDecoration(
          color: context.raisedColor,
          borderRadius: AppRadius.secondaryCircular,
        ),
        child: Row(
          children: [
            _buildFilterButton(
              icon: AppIcons.transferV,
              label: 'Sırala',
              onTap: () {},
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            _buildFilterButton(
              icon: AppIcons.menu2,
              label: 'Kategoriler',
              isActive: _selectedCategory != ListExplorePagemodel._all,
              onTap: _showCategoryFilterSheet,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            _buildFilterButton(
              icon: AppIcons.moneyBag,
              label: 'Ücret',
              isActive: _selectedPriceRange != ListExplorePagemodel._all,
              onTap: _showPriceFilterSheet,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            _buildFilterButton(
              icon: AppIcons.route,
              label: 'Mesafe',
              isActive: _selectedDistance != ListExplorePagemodel._all,
              onTap: _showDistanceFilterSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton({
    required AppIconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final activeColor = context.accentColor;
    final foreground = isActive ? activeColor : context.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: AppSizes.filterButton,
          padding: AppPadding.horizontalSmall,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: _activeFilterAlpha)
                : context.raisedColor,
            borderRadius: AppRadius.secondaryCircular,
            border: Border.all(
              color: isActive ? activeColor : context.dividerColor,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: AppSizes.iconSmall, color: foreground),
              const SizedBox(width: AppSizes.spaceTiny),
              Flexible(
                child: Text(
                  label,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ AppBar

  SliverAppBar appBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: false,
      stretch: true,
      expandedHeight: _appBarHeight,
      collapsedHeight: _appBarHeight,
      elevation: 0,
      backgroundColor: context.raisedColor,
      surfaceTintColor: context.raisedColor,
      clipBehavior: Clip.hardEdge,
      title: Text(
        'KOALA',
        style: context.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.accentColor,
        ),
      ),
      centerTitle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.secondaryBottom,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.secondaryBottom,
            color: context.raisedColor,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _searchField(),
                  const SizedBox(height: AppSizes.space),
                ],
              ),
              const SizedBox(width: AppSizes.spaceMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      // Açıkken ekranın iki yanında ana boşluk kadar pay bırakır.
      width: isOpen
          ? context.width - AppPadding.primary * 2
          : _collapsedSearchWidth,
      height: AppSizes.fieldHeight,
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: context.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: "İş, şirket veya konum ara...",
          hintStyle: context.textTheme.bodyLarge?.copyWith(
            color: context.textTertiary,
          ),
          filled: true,
          fillColor: isOpen ? context.tileColor : Colors.transparent,
          border: const OutlineInputBorder(
            borderRadius: AppRadius.stadiumCircular,
            borderSide: BorderSide.none,
          ),
          prefixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: AppSizes.iconMedium,
                    color: context.textSecondary,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          suffixIcon: IconButton(
            icon: const AppIcon(AppIcons.search, size: AppSizes.icon),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(context.accentColor),
              padding: const WidgetStatePropertyAll(AppPadding.iconButton),
            ),
            color: context.onAccentColor,
            onPressed: () {
              if (_searchFocusNode.hasFocus) {
                _searchFocusNode.unfocus();
              } else {
                _searchFocusNode.requestFocus();
              }
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Filtre sheet

  void _showCategoryFilterSheet() {
    _showCategoryFilter();
    _openFilterSheet(
      title: 'Kategoriler',
      // Kategori satırları sunucudan geliyor; tip seçenekleri sabit kalıyor
      // çünkü onların karşılığı `JobType` enum'ı. Kategorinin değeri **id**:
      // sunucu `categoryId` bekliyor, `code` yalnızca ikon ve renk eşlemesi
      // için var. İkisi is-koala/koala#32'de ayrı bölümlere ayrılacak.
      options: [
        ('Tümü', ListExplorePagemodel._all),
        for (final type in JobType.values) (type.displayName, type.name),
        for (final category in context.read<JobCategoryProvider>().categories)
          (category.displayName, category.id),
      ],
      selected: () => _tempCategory,
      onSelect: (value) => _tempCategory = value,
    );
  }

  void _showPriceFilterSheet() {
    _showPriceFilter();
    _openFilterSheet(
      title: 'Ücret Aralığı',
      options: const [
        ('Tümü', ListExplorePagemodel._all),
        ('0-500₺', '0-500'),
        ('500-1000₺', '500-1000'),
        ('1000-2000₺', '1000-2000'),
        ('2000₺+', '2000+'),
      ],
      selected: () => _tempPriceRange,
      onSelect: (value) => _tempPriceRange = value,
    );
  }

  void _showDistanceFilterSheet() {
    _showDistanceFilter();
    _openFilterSheet(
      title: 'Mesafe',
      // Kovalar "X km içinde": sunucu sınırlayıcı kutu süzüyor ve kutu bir
      // halkanın **dışını** ifade edemiyor, o yüzden eski "20+ km" seçeneği
      // yok.
      options: const [
        ('Tümü', ListExplorePagemodel._all),
        ('5 km içinde', '0-5'),
        ('10 km içinde', '0-10'),
        ('20 km içinde', '0-20'),
      ],
      selected: () => _tempDistance,
      onSelect: (value) => _tempDistance = value,
    );
  }

  /// Üç filtre sheet'i de aynı iskeleti kullanıyor: başlık, seçenek hapları
  /// ve uygula butonu. Seçim sheet'in kendi `setState`'iyle güncelleniyor,
  /// sayfaya ancak "Uygula"ya basılınca yansıyor.
  void _openFilterSheet({
    required String title,
    required List<(String label, String value)> options,
    required String Function() selected,
    required ValueChanged<String> onSelect,
  }) {
    AppBottomSheet.show(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppBottomSheet(
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSizes.spaceSmall,
                runSpacing: AppSizes.spaceSmall,
                children: [
                  for (final (label, value) in options)
                    _buildFilterChip(
                      label,
                      value,
                      selected(),
                      (val) => setModalState(() => onSelect(val)),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              _buildApplyButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onTap,
  ) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppPadding.primary,
          vertical: AppSizes.space,
        ),
        decoration: BoxDecoration(
          color: isSelected ? context.accentColor : context.tileColor,
          borderRadius: AppRadius.secondaryCircular,
        ),
        child: Text(
          label,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isSelected ? context.onAccentColor : context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      height: AppSizes.buttonHeightCompact,
      child: ElevatedButton(
        onPressed: _applyTempFilters,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.accentColor,
          foregroundColor: context.onAccentColor,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.innerCircular,
          ),
          elevation: 0,
        ),
        // textTheme slotları renk taşıyor; verilmezse buton zemini yeşil
        // olduğu hâlde metin koyu kalır.
        child: Text(
          'Uygula',
          style: context.textTheme.titleSmall?.copyWith(
            color: context.onAccentColor,
          ),
        ),
      ),
    );
  }
}
