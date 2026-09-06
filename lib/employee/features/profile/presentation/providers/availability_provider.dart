import 'package:flutter/material.dart';
import 'package:koala/product/services/availability_service.dart';
import 'package:koala/product/models/availability.dart';
import 'package:koala/product/models/availability_day.dart';
import 'package:koala/product/models/availability_exception.dart';
import 'package:koala/product/models/availability_slot.dart';
import 'package:koala/product/network/api_exception.dart';

/// Oturum sahibinin müsaitlik ekranı için tek durum modülü.
///
/// Düzenleme taslağını burada tutmasının önemli bir nedeni var: backend'in
/// `PUT /users/me/availability` ucu kısmi güncelleme değil. Arayüz bir günü
/// değiştirir, [saveWeekly] ise her zaman eldeki **bütün** haftayı yollar.
class AvailabilityProvider extends ChangeNotifier {
  AvailabilityProvider({AvailabilityService? service})
    : _service = service ?? AvailabilityService();

  static const int _maximumSlotCount = 50;
  static const int _maximumNoteLength = 255;

  final AvailabilityService _service;
  final List<AvailabilitySlot> _draftSlots = [];

  Availability? _availability;
  String? _loadedUserId;
  int _stateGeneration = 0;
  bool _isLoadInFlight = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  Availability? get availability => _availability;

  List<AvailabilitySlot> get draftSlots => List.unmodifiable(_draftSlots);

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  bool isLoadedFor(String userId) =>
      _loadedUserId == userId && _availability != null;

  List<AvailabilitySlot> slotsForDay(AvailabilityDay day) =>
      _draftSlots.where((slot) => slot.day == day).toList(growable: false);

  /// Haftalık şablonu ve yaklaşan istisnaları sunucudan getirir.
  Future<void> load(String userId, {bool silent = false}) async {
    if (_isLoadInFlight || _isSaving) return;
    _isLoadInFlight = true;
    final generation = ++_stateGeneration;

    _isLoading = !silent || _availability == null;
    _errorMessage = null;
    notifyListeners();

    try {
      final availability = await _service.fetchForUser(userId);
      if (generation != _stateGeneration) return;
      _availability = availability;
      _loadedUserId = userId;
      _draftSlots
        ..clear()
        ..addAll(_ordered(availability.slots));
    } on ApiException catch (error) {
      if (generation == _stateGeneration) _errorMessage = error.message;
    } finally {
      if (generation == _stateGeneration) {
        _isLoadInFlight = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Bir günün taslağını değiştirir; diğer günleri olduğu gibi bırakır.
  bool replaceDaySlots(
    String userId,
    AvailabilityDay day,
    List<AvailabilitySlot> slots,
  ) {
    if (!_canMutate(userId) || _isSaving) return false;

    _draftSlots
      ..removeWhere((slot) => slot.day == day)
      ..addAll(slots.map((slot) => slot.copyWith(day: day)));
    _draftSlots.sort(_compareSlots);
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  /// Taslaktaki bütün haftayı sunucuya kaydeder.
  Future<bool> saveWeekly(String userId) async {
    if (!_canMutate(userId)) return false;

    final validationMessage = _validateSlots(_draftSlots);
    if (validationMessage != null) {
      _errorMessage = validationMessage;
      notifyListeners();
      return false;
    }

    return _runSave<Availability>(
      userId: userId,
      request: () => _service.replaceSlots(_ordered(_draftSlots)),
      apply: (saved) {
        // Haftalık PUT yanıtı sözleşme gereği istisnaları boş döndürüyor.
        // İstisnalar ayrı uçtan yönetildiği için eldeki listeyi koruyoruz.
        _availability = Availability(
          slots: saved.slots,
          exceptions: _availability?.exceptions ?? const [],
        );
        _draftSlots
          ..clear()
          ..addAll(_ordered(saved.slots));
      },
    );
  }

  /// Tarih istisnasını ekler veya aynı tarihteki kaydı günceller.
  Future<bool> saveException({
    required String userId,
    required DateTime date,
    required bool available,
    String? note,
  }) async {
    if (!_canMutate(userId)) return false;

    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = DateUtils.dateOnly(date);
    if (selectedDate.isBefore(today)) {
      _errorMessage = 'Geçmiş bir tarih için istisna ekleyemezsin.';
      notifyListeners();
      return false;
    }
    if ((note?.length ?? 0) > _maximumNoteLength) {
      _errorMessage = 'Not en fazla 255 karakter olabilir.';
      notifyListeners();
      return false;
    }

    return _runSave<AvailabilityException>(
      userId: userId,
      request: () => _service.saveException(
        date: selectedDate,
        available: available,
        note: note,
      ),
      apply: (saved) {
        final exceptions = [
          ...?_availability?.exceptions.where(
            (item) => !DateUtils.isSameDay(item.date, saved.date),
          ),
          saved,
        ]..sort((left, right) => left.date.compareTo(right.date));

        _availability = Availability(
          slots: _availability?.slots ?? const [],
          exceptions: exceptions,
        );
      },
    );
  }

  /// Tarih istisnasını siler ve başarılı olduğunda görünür listeden çıkarır.
  Future<bool> deleteException(String userId, String exceptionId) {
    return _runSave<void>(
      userId: userId,
      request: () => _service.deleteException(exceptionId),
      apply: (_) {
        _availability = Availability(
          slots: _availability?.slots ?? const [],
          exceptions: [
            ...?_availability?.exceptions.where(
              (item) => item.id != exceptionId,
            ),
          ],
        );
      },
    );
  }

  /// Çıkışta önceki kullanıcının şablonu sonraki oturumda görünmesin.
  void clear() {
    _stateGeneration++;
    _availability = null;
    _loadedUserId = null;
    _draftSlots.clear();
    _isLoadInFlight = false;
    _isLoading = false;
    _isSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  bool _canMutate(String userId) {
    return !_isLoadInFlight && isLoadedFor(userId);
  }

  Future<bool> _runSave<T>({
    required String userId,
    required Future<T> Function() request,
    required void Function(T value) apply,
  }) async {
    if (_isSaving || !_canMutate(userId)) return false;

    final generation = _stateGeneration;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final value = await request();
      if (generation != _stateGeneration || !isLoadedFor(userId)) return false;
      apply(value);
      return true;
    } on ApiException catch (error) {
      if (generation == _stateGeneration) _errorMessage = error.message;
      return false;
    } finally {
      if (generation == _stateGeneration) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  static String? _validateSlots(List<AvailabilitySlot> slots) {
    if (slots.length > _maximumSlotCount) {
      return 'En fazla 50 saat aralığı ekleyebilirsin.';
    }

    try {
      for (final slot in slots) {
        if (slot.startMinutes >= slot.endMinutes) {
          return 'Bitiş saati başlangıç saatinden sonra olmalı.';
        }
      }

      final ordered = _ordered(slots);
      for (var index = 1; index < ordered.length; index++) {
        final previous = ordered[index - 1];
        final current = ordered[index];
        if (previous.day == current.day &&
            current.startMinutes < previous.endMinutes) {
          return 'Aynı gün içindeki saat aralıkları çakışamaz.';
        }
      }
    } on FormatException {
      return 'Saat bilgisi geçerli değil.';
    }

    return null;
  }

  static List<AvailabilitySlot> _ordered(List<AvailabilitySlot> slots) {
    return [...slots]..sort(_compareSlots);
  }

  static int _compareSlots(AvailabilitySlot left, AvailabilitySlot right) {
    final dayComparison = left.day.order.compareTo(right.day.order);
    if (dayComparison != 0) return dayComparison;
    return left.startMinutes.compareTo(right.startMinutes);
  }
}
