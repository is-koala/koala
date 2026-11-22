import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_filter_selection.dart';
import 'package:koala/employee/features/home/models/job_map_bounds.dart';
import 'package:koala/employee/features/home/models/job_cluster.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/map_explore_controller.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/search_provider.dart';
import 'package:koala/employee/features/home/presentation/widgets/explore_brand_title.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_filter_sheet.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_cache.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_cluster_sheet.dart';
import 'package:koala/employee/features/home/presentation/widgets/map_explore_overlay.dart';
import 'package:koala/employee/features/home/services/location_service.dart';
import 'package:koala/product/constants/app_shadows.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_map.dart';
import 'package:koala/product/constants/app_map_style.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:provider/provider.dart';

part 'map_explore_pagemodel.dart';

class MapExplorePage extends StatefulWidget {
  const MapExplorePage({super.key, this.controller});

  /// Testler için; üretimde `null` ve sayfa kendi kontrolcüsünü kurar. Pinlerin
  /// yetki değişince yenilendiği yalnız gerçek ilan akışında sınanabiliyor.
  /// Sahipliği sayfaya geçer.
  final MapExploreController? controller;

  @override
  State<MapExplorePage> createState() => _MapExplorePageState();
}

class _MapExplorePageState extends MapExplorePageModel {
  static const double _locationButtonSize = 40;

  static const String unavailableTitle = 'Harita bu derlemede kullanılamıyor';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!mapsAvailable) return unavailableView();
    final searchProvider = context.watch<SearchProvider>();

    final isSearching =
        searchProvider.isSearching && _searchController.text.isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar(searchProvider),
      body: Stack(
        children: [
          map(),
          if (_loading) loadingOverlay(),

          // Hangi kartın çizileceğine `MapExploreOverlay` karar veriyor; buraya
          // `if` eklemek hatayı arama açıkken yutan kusuru geri getirir.
          Positioned(
            top: context.padding.top + kToolbarHeight + AppSizes.spaceSmall,
            left: AppPadding.primary,
            right: AppPadding.primary,
            child: MapExploreOverlay(
              isSearching: isSearching,
              isLoading: _jobs.isInitialLoading,
              isRefreshing: _jobs.isRefreshing,
              errorMessage: _jobs.errorMessage,
              isTruncated: _jobs.isTruncated,
              jobs: _jobs.jobs,
              onRetry: _jobs.retry,
              onJobTap: _focusOnJob,
            ),
          ),

          currentPositionButton(),
        ],
      ),
    );
  }

  /// Harita anahtarı olmayan derlemede (#172) `GoogleMap` kurulmaz, iOS'ta
  /// çöküyor; düğme listeye götürür.
  Scaffold unavailableView() {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        title: const ExploreBrandTitle(),
        centerTitle: false,
      ),
      body: EmptyState(
        key: const ValueKey('map-unavailable'),
        icon: AppIcons.location,
        title: unavailableTitle,
        description: 'İlanları liste görünümünden görebilirsiniz.',
        action: TextButton(
          onPressed: context.read<PageProvider>().setExploreViewToList,
          child: const Text('Listeye geç'),
        ),
      ),
    );
  }

  /// Yer varsa navbar'ın sağında, alt kenarı hizalı; dar ekranda üstünde.
  double _locationButtonBottom(BuildContext context) {
    const navBarBottom = AppPadding.bottomNavBarPadding;
    final sideRoom =
        (MediaQuery.sizeOf(context).width - AppSizes.navBarWidth) / 2;
    final fitsBeside = sideRoom >= _locationButtonSize + AppPadding.primary * 2;

    return fitsBeside
        ? navBarBottom.bottom
        : navBarBottom.bottom + AppSizes.navBar + AppSizes.spaceMedium;
  }

  Positioned currentPositionButton() {
    return Positioned(
      bottom: _locationButtonBottom(context),
      right: AppPadding.primary,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppShadows.floating,
        ),
        child: FloatingActionButton(
          mini: true,
          // Mini FAB'ın 48'lik dokunma payı gölgeyi kalın gösteriyordu.
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: context.accentColor,
          foregroundColor: context.onAccentColor,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          onPressed: () {
            if (_currentLatLng != null && _mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _currentLatLng!, zoom: 15.0),
                ),
              );
              HapticFeedback.lightImpact();
            }
          },
          child: const Icon(Icons.my_location, size: AppSizes.icon),
        ),
      ),
    );
  }

  Container loadingOverlay() {
    return Container(
      color: AppColors.scrim.withValues(alpha: 0.2),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(context.accentColor),
              strokeWidth: 3.0,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            Text(
              _loadingMessage,
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppColors.onAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  GoogleMap map() {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentLatLng ?? AppMap.istanbulCenter,
        zoom: 15.0,
      ),
      mapType: MapType.normal,
      style: AppMapStyle.of(context),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      // Android'in pin araç çubuğu; kart kendi eylemlerini taşıyor.
      mapToolbarEnabled: false,
      markers: _markers,
      // Yaklaşık konumun belirsizlik dairesi; pin tek başına bir nokta iddiası
      // (ADR-0003, #93).
      circles: _areas,
      // Hangi ilanların çekileceğini kullanıcının baktığı yer belirliyor.
      onCameraMove: (position) => _zoom = position.zoom,
      onCameraIdle: _onCameraIdle,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;

        setState(() {
          _loadingMessage = 'Konum Alınıyor...';
        });

        if (_currentLatLng != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_currentLatLng!, 16),
          );
        }

        // İlk çizim "durdu" sayılmıyor; ilk kutu elle gönderiliyor.
        unawaited(_onCameraIdle());
      },
      onTap: (_) {
        final searchProvider = Provider.of<SearchProvider>(
          context,
          listen: false,
        );
        if (searchProvider.isSearching) {
          _resetSearch(searchProvider);
        }
      },
    );
  }

  AppBar appBar(SearchProvider searchProvider) {
    // Harita iki temada açık çizdiği için durum çubuğu ikonları sabit koyu.
    const overMapStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );

    if (searchProvider.isSearching) {
      return AppBar(
        // Arama açıkken ikon parlaklığını Flutter zeminden çıkarsın.
        backgroundColor: context.backgroundColor,
        elevation: 2,
        shadowColor: AppColors.barShadow,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.textPrimary),
          onPressed: () => _resetSearch(searchProvider),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          onChanged: (value) {
            _onMapSearch(value);
            setState(() {});
          },
          style: context.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'İş, şirket veya konum ara...',
            hintStyle: context.textTheme.bodyLarge?.copyWith(
              color: context.textTertiary,
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: context.textSecondary),
              onPressed: () {
                _searchController.clear();
                _onMapSearch('');
                setState(() {});
              },
            ),
        ],
      );
    }

    return AppBar(
      systemOverlayStyle: overMapStyle,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const ExploreBrandTitle(floating: true),
      centerTitle: false,
      actions: [
        // Filtre ve arama tek yeşil hapta; zeminsiz ikon sokak adlarında
        // kayboluyordu. 48'lik `IconButton` hapı şişirdiği için kare düğmeler.
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.accentColor,
            borderRadius: AppRadius.stadiumCircular,
            boxShadow: AppShadows.floating,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pillButton(
                tooltip: 'Filtrele ve sırala',
                // Düğme sıralamayı da açıyor; huni yalnız "filtre" diyordu.
                icon: AppIcons.sort,
                onPressed: _openFilterSheet,
              ),
              _pillButton(
                tooltip: 'Ara',
                icon: AppIcons.search,
                onPressed: searchProvider.startSearching,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.spaceMedium),
      ],
    );
  }

  Widget _pillButton({
    required String tooltip,
    required AppIconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: AppSizes.mapPillHeight,
        height: AppSizes.mapPillHeight,
      ),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: AppIcon(icon, color: context.onAccentColor),
      onPressed: onPressed,
    );
  }

  void _resetSearch(SearchProvider searchProvider) {
    searchProvider.stopSearching();
    _searchController.clear();
    _searchFocusNode.unfocus();
    _onMapSearch('');
  }
}
