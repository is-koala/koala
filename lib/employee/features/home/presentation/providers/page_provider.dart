import 'package:flutter/material.dart';

enum ExploreViewType { map, list }

enum JobsViewType { home, saved }

class PageProvider with ChangeNotifier {
  /// [exploreViewType] keşfin açılış görünümü. Varsayılan harita; harita bu
  /// derlemede kullanılamıyorsa (`MapsAvailability`) uygulama listeyle açar,
  /// kullanıcı yer tutucuya bakarak başlamasın.
  PageProvider({ExploreViewType exploreViewType = ExploreViewType.map})
    : _exploreViewType = exploreViewType;

  ExploreViewType _exploreViewType;
  JobsViewType _jobsViewType = JobsViewType.home;

  ExploreViewType get exploreViewType => _exploreViewType;
  JobsViewType get jobsViewType => _jobsViewType;

  // Explore view type değiştirme
  void setExploreViewType(ExploreViewType viewType) {
    if (_exploreViewType != viewType) {
      _exploreViewType = viewType;
      notifyListeners();
    }
  }

  void toggleExploreView() {
    setExploreViewType(
      _exploreViewType == ExploreViewType.map
          ? ExploreViewType.list
          : ExploreViewType.map,
    );
  }

  // PageProvider'a eklenecek metodlar
  void setExploreViewToMap() {
    _exploreViewType = ExploreViewType.map;
    notifyListeners();
  }

  void setExploreViewToList() {
    _exploreViewType = ExploreViewType.list;
    notifyListeners();
  }

  // Jobs view type değiştirme
  void setJobsViewType(JobsViewType viewType) {
    if (_jobsViewType != viewType) {
      _jobsViewType = viewType;
      notifyListeners();
    }
  }

  void toggleJobsView() {
    setJobsViewType(
      _jobsViewType == JobsViewType.home
          ? JobsViewType.saved
          : JobsViewType.home,
    );
  }
}
