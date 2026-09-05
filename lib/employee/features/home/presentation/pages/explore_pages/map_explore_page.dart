import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:koala/employee/core/widgets/job_detail_bottom_sheet.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/search_provider.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_marker_generator.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/home/services/location_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_map.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

part 'map_explore_pagemodel.dart';

class MapExplorePage extends StatefulWidget {
  const MapExplorePage({super.key});

  @override
  State<MapExplorePage> createState() => _MapExplorePageState();
}

class _MapExplorePageState extends MapExplorePageModel {
  /// Arama sonucu listesinin ekranın en fazla ne kadarını kaplayacağı.
  /// Altındaki harita görünür kalmalı ki kullanıcı nereye baktığını bilsin.
  static const double _overlayMaxHeightRatio = 0.4;

  /// Konum butonunun alttan yüksekliği: navbar'ın üstünde kalmalı.
  static const double _locationButtonBottom = 110;

  /// Harita üstündeki kartların gölge yüksekliği.
  static const double _overlayElevation = 8;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searchProvider = context.watch<SearchProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar(searchProvider),
      body: Stack(
        children: [
          map(),
          if (_loading) loadingOverlay(),

          // Arama sonuçları overlay
          if (searchProvider.isSearching && _searchResults.isNotEmpty)
            _searchResultsOverlay(),

          // Arama aktifken ve sonuç yoksa
          if (searchProvider.isSearching &&
              _searchController.text.isNotEmpty &&
              _searchResults.isEmpty)
            _noResultsOverlay(),

          currentPositionButton(),
        ],
      ),
    );
  }

  /// Harita üstünde duran kartların ortak sarmalayıcısı.
  Widget _overlayCard({required Widget child}) {
    return Positioned(
      top: context.padding.top + kToolbarHeight + AppSizes.spaceSmall,
      left: AppPadding.primary,
      right: AppPadding.primary,
      child: Material(
        elevation: _overlayElevation,
        borderRadius: AppRadius.secondaryCircular,
        color: context.backgroundColor,
        child: child,
      ),
    );
  }

  Widget _searchResultsOverlay() {
    return _overlayCard(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * _overlayMaxHeightRatio,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceSmall),
          itemCount: _searchResults.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            indent: AppPadding.primary,
            endIndent: AppPadding.primary,
          ),
          itemBuilder: (context, index) =>
              _searchResultTile(_searchResults[index]),
        ),
      ),
    );
  }

  Widget _searchResultTile(Job job) {
    return ListTile(
      leading: Container(
        width: AppSizes.iconCircle,
        height: AppSizes.iconCircle,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: job.category.color.withValues(alpha: 0.15),
          borderRadius: AppRadius.smallCircular,
        ),
        child: AppIcon(
          job.category.icon,
          color: job.category.color,
          size: AppSizes.iconMedium,
        ),
      ),
      title: Text(
        job.title,
        style: context.textTheme.labelLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${job.company ?? ''} • ${job.locationLabel ?? ''}',
        style: context.textTheme.labelMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '₺${job.price.toStringAsFixed(0)}',
        style: context.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.accentColor,
        ),
      ),
      onTap: () => _focusOnJob(job),
    );
  }

  Widget _noResultsOverlay() {
    return _overlayCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spaceLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.searchList,
              size: AppSizes.iconLarge,
              color: context.textTertiary,
            ),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              'Sonuç bulunamadı',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              'Farklı bir arama terimi deneyin',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Positioned currentPositionButton() {
    return Positioned(
      bottom: _locationButtonBottom,
      right: AppPadding.primary,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: context.accentColor,
        foregroundColor: context.onAccentColor,
        elevation: 4,
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
    );
  }

  Container loadingOverlay() {
    return Container(
      // Karartma haritanın üstünde; temadan bağımsız koyu kalıyor.
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
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: _markers,
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
      },
      onTap: (_) {
        // Haritaya tıklanınca aramayı kapat
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
    // Appbar saydamken arkasında harita var: harita iki temada da açık
    // çizdiği için durum çubuğu ikonları sabit koyu kalmalı.
    const overMapStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );

    if (searchProvider.isSearching) {
      return AppBar(
        // Arama açıkken appbar'ın kendi zemini var; ikon parlaklığını
        // Flutter o zeminden çıkarsın, yoksa koyu temada koyu ikon koyu
        // zeminde kayboluyor.
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
            searchProvider.setQuery(value);
            _onMapSearch(value);
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
                searchProvider.clearQuery();
                _onMapSearch('');
              },
            ),
        ],
      );
    }

    return AppBar(
      systemOverlayStyle: overMapStyle,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        'KOALA',
        style: context.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.accentColor,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: AppIcon(AppIcons.search, color: context.onAccentColor),
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(context.accentColor),
          ),
          onPressed: searchProvider.startSearching,
        ),
        const SizedBox(width: AppSizes.spaceMedium),
      ],
    );
  }

  void _resetSearch(SearchProvider searchProvider) {
    searchProvider.stopSearching();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResults = [];
    });
  }
}
