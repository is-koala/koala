import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/talent_pool_entry.dart';
import 'package:koala/business/features/home/services/talent_pool_service.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/product/network/api_exception.dart';

/// Havuz üyeliği. Liste sayfalı olduğu için "listede yok" demek "havuzda
/// yok" demek değildir: henüz yüklenmemiş bir sayfada duruyor olabilir.
///
/// Bilinmiyorken düğme iyimser `PUT` atmaz — gövdesiz `PUT` var olan notu
/// siler.
enum TalentPoolMembership { yes, no, unknown }

/// İşverenin yetenek havuzu.
///
/// Ekleme ve çıkarma iyimser: ikon dokunulduğu anda değişir, sunucu
/// reddederse geri alınır. Üyelik [isInPool] üç durumludur; bilinmiyorken
/// kalan sayfalar çekilmeden `PUT` atılmaz.
class BTalentPoolProvider extends ChangeNotifier {
  BTalentPoolProvider({TalentPoolService? service})
    : _service = service ?? TalentPoolService();

  final TalentPoolService _service;

  final List<TalentPoolEntry> _entries = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _isLast = false;
  int _page = 0;
  String? _errorMessage;
  int _generation = 0;

  List<TalentPoolEntry> get entries => List.unmodifiable(_entries);

  bool get isLoading => _isLoading;

  bool get isLoadingMore => _isLoadingMore;

  bool get hasLoaded => _hasLoaded;

  bool get hasMore => !_isLast;

  String? get errorMessage => _errorMessage;

  /// Üyelik, yüklenmiş sayfalara bakarak cevaplanır.
  ///
  /// Son sayfa gelmeden listede görünmeyen biri için [unknown] döner;
  /// "yok" demek o kayda gövdesiz `PUT` attırırdı.
  TalentPoolMembership isInPool(String workerId) {
    if (_entries.any((entry) => entry.worker.id == workerId)) {
      return TalentPoolMembership.yes;
    }
    if (_hasLoaded && _isLast) return TalentPoolMembership.no;
    return TalentPoolMembership.unknown;
  }

  Future<void> load({bool force = false}) async {
    if (_isLoading) return;
    if (_hasLoaded && !force && _errorMessage == null) return;

    final generation = _generation;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final page = await _service.fetchTalentPool(page: 0);
      if (generation != _generation) return;
      _entries
        ..clear()
        ..addAll(page.entries);
      _page = page.page;
      _isLast = page.last;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _errorMessage = _messageFor(error);
        _isLast = false;
      }
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || _isLast) return;

    final generation = _generation;
    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _service.fetchTalentPool(page: _page + 1);
      if (generation != _generation) return;
      _entries.addAll(page.entries);
      _page = page.page;
      _isLast = page.last;
    } on ApiException catch (error) {
      if (generation == _generation) _errorMessage = _messageFor(error);
    } finally {
      if (generation == _generation) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Üyelik bilinmiyorsa kalan sayfalar çekilir; bilinmiyorken `PUT`
  /// atılmaz.
  Future<TalentPoolMembership> ensureMembership(String workerId) async {
    var membership = isInPool(workerId);
    if (membership != TalentPoolMembership.unknown) return membership;

    if (!_hasLoaded || _errorMessage != null) {
      await load(force: _errorMessage != null);
      membership = isInPool(workerId);
      if (membership != TalentPoolMembership.unknown) return membership;
    }

    while (isInPool(workerId) == TalentPoolMembership.unknown && !_isLast) {
      final before = _entries.length;
      await loadMore();
      if (_entries.length == before && !_isLast) {
        // Sayfa eklenemedi; döngüye girmemek için dur.
        break;
      }
    }
    return isInPool(workerId);
  }

  /// İşçiyi havuza ekler. Zaten havuzdaysa notu günceller; not yoksa
  /// gövdesiz `PUT` atılmaz.
  Future<bool> addWorker(JobCreator worker, {String? note}) async {
    if (isInPool(worker.id) == TalentPoolMembership.yes && note == null) {
      return true;
    }

    final generation = _generation;
    _errorMessage = null;
    final existing = _indexOf(worker.id);
    TalentPoolEntry? replaced;
    if (existing >= 0) {
      replaced = _entries[existing];
      _entries[existing] = TalentPoolEntry(
        id: replaced.id,
        worker: replaced.worker,
        companyId: replaced.companyId,
        note: note,
        createdAt: replaced.createdAt,
      );
    } else {
      _entries.insert(
        0,
        TalentPoolEntry(id: worker.id, worker: worker, note: note),
      );
    }
    notifyListeners();

    try {
      final saved = await _service.addWorker(worker.id, note: note);
      if (generation != _generation) return false;
      final index = _indexOf(worker.id);
      if (index >= 0) _entries[index] = saved;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (generation != _generation) return false;
      if (replaced != null) {
        final index = _indexOf(worker.id);
        if (index >= 0) _entries[index] = replaced;
      } else {
        _entries.removeWhere((entry) => entry.worker.id == worker.id);
      }
      _errorMessage = _messageFor(error);
      notifyListeners();
      return false;
    }
  }

  /// Havuzdaysa çıkarır, değilse notla ekler. Üyelik bilinmiyorsa önce
  /// sayfalar yüklenir; bilinmiyorken `PUT` atılmaz.
  Future<bool> toggleWorker(JobCreator worker, {String? note}) async {
    final membership = await ensureMembership(worker.id);
    if (membership == TalentPoolMembership.unknown) {
      return false;
    }
    if (membership == TalentPoolMembership.yes) {
      return removeWorker(worker.id);
    }
    return addWorker(worker, note: note);
  }

  Future<bool> removeWorker(String workerId) async {
    final index = _indexOf(workerId);
    if (index < 0) return true;

    final removed = _entries.removeAt(index);
    final generation = _generation;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.removeWorker(workerId);
      return generation == _generation;
    } on ApiException catch (error) {
      if (generation == _generation) {
        _entries.insert(index, removed);
        _errorMessage = _messageFor(error);
        notifyListeners();
      }
      return false;
    }
  }

  String _messageFor(ApiException error) {
    switch (error.errorCode) {
      case 'TALENT_CANNOT_ADD_SELF':
        return 'Kendinizi yetenek havuzuna ekleyemezsiniz.';
    }
    return error.message;
  }

  int _indexOf(String workerId) {
    return _entries.indexWhere((entry) => entry.worker.id == workerId);
  }

  void clear() {
    _generation++;
    _entries.clear();
    _isLoading = false;
    _isLoadingMore = false;
    _hasLoaded = false;
    _isLast = false;
    _page = 0;
    _errorMessage = null;
    notifyListeners();
  }
}
