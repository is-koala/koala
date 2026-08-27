import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';

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
    return GestureDetector(
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        // Kartlar zeminden yükselsin diye sayfa geri çekilmiş bir ton.
        backgroundColor: context.recessedColor,
        extendBody: true,
        extendBodyBehindAppBar: false,
        body: CustomScrollView(
          slivers: [
            appBar(context),
            const SliverToBoxAdapter(child: SizedBox(height: AppSizes.space)),
            filters(),
            if (_searchQuery.isNotEmpty)
              SliverToBoxAdapter(child: _searchSummary()),
            SliverToBoxAdapter(child: _listHeader()),
            if (_loading)
              SliverToBoxAdapter(child: _centered(_loadingIndicator()))
            else if (_filteredJobs.isEmpty)
              SliverToBoxAdapter(child: _centered(_emptyState()))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final job = _filteredJobs[index];
                  return JobCard(job: job, distance: _getDistance(job));
                }, childCount: _filteredJobs.length),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppSizes.navBarClearance),
            ),
          ],
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

  Widget _listHeader() {
    return Padding(
      padding: AppPadding.primaryHorizontal,
      child: Text('Yakındaki İşler', style: context.textTheme.titleMedium),
    );
  }

  Widget _searchSummary() {
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
            '"$_searchQuery" için ${_filteredJobs.length} sonuç',
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

  Widget _emptyState() {
    return Column(
      children: [
        AppIcon(
          AppIcons.searchList,
          size: AppSizes.iconHuge,
          color: context.textTertiary,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Text(
          _searchQuery.isNotEmpty
              ? '"$_searchQuery" ile eşleşen iş bulunamadı'
              : 'Bu filtreye uygun iş bulunamadı',
          textAlign: TextAlign.center,
          style: context.textTheme.bodyLarge?.copyWith(
            color: context.textSecondary,
          ),
        ),
        if (_searchQuery.isNotEmpty) ...[
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
              isActive: _selectedFilter != 'all',
              onTap: _showCategoryFilterSheet,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            _buildFilterButton(
              icon: AppIcons.moneyBag,
              label: 'Ücret',
              isActive: _selectedPriceRange != 'all',
              onTap: _showPriceFilterSheet,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            _buildFilterButton(
              icon: AppIcons.route,
              label: 'Mesafe',
              isActive: _selectedDistance != 'all',
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
          prefixIcon: _searchQuery.isNotEmpty
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
      options: const [
        ('Tümü', 'all'),
        ('Günlük', 'oneTime'),
        ('Tekrarlı', 'recurring'),
        ('Fotoğrafçılık', 'photography'),
        ('Garsonluk', 'waiter'),
        ('Hayvan Bakımı', 'petCare'),
        ('Tasarım', 'design'),
        ('Barista', 'barista'),
      ],
      selected: () => _tempFilter,
      onSelect: (value) => _tempFilter = value,
    );
  }

  void _showPriceFilterSheet() {
    _showPriceFilter();
    _openFilterSheet(
      title: 'Ücret Aralığı',
      options: const [
        ('Tümü', 'all'),
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
      options: const [
        ('Tümü', 'all'),
        ('0-5 km', '0-5'),
        ('5-10 km', '5-10'),
        ('10-20 km', '10-20'),
        ('20+ km', '20+'),
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
