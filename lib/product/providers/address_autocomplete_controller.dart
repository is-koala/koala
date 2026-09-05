import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/address_search_service.dart';

class AddressAutocompleteController extends ChangeNotifier {
  AddressAutocompleteController({
    required AddressSearchGateway gateway,
    Duration debounce = const Duration(milliseconds: 350),
  }) : _gateway = gateway,
       _debounce = debounce;

  final AddressSearchGateway _gateway;
  final Duration _debounce;

  Timer? _timer;
  AddressSearchSession? _session;
  int _revision = 0;
  List<AddressSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _resolving = false;
  String? _errorMessage;

  List<AddressSuggestion> get suggestions => _suggestions;
  bool get searching => _searching;
  bool get resolving => _resolving;
  String? get errorMessage => _errorMessage;

  void queryChanged(String rawQuery) {
    final query = rawQuery.trim();
    final revision = ++_revision;
    _timer?.cancel();
    _errorMessage = null;

    if (query.length < 3) {
      _suggestions = const [];
      _searching = false;
      notifyListeners();
      return;
    }

    _searching = true;
    notifyListeners();
    _timer = Timer(_debounce, () => _search(query, revision));
  }

  Future<AddressCandidate?> select(AddressSuggestion suggestion) async {
    final session = _session;
    if (session == null || _resolving) return null;

    _timer?.cancel();
    _revision++;
    _resolving = true;
    _searching = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final candidate = await _gateway.resolve(session.id, suggestion.id);
      _session = null;
      _suggestions = const [];
      return candidate;
    } on ApiException catch (error) {
      if (error.statusCode == 400) _session = null;
      _errorMessage = error.message;
      return null;
    } finally {
      _resolving = false;
      notifyListeners();
    }
  }

  void retry(String query) {
    _session = null;
    queryChanged(query);
  }

  Future<void> _search(String query, int revision) async {
    try {
      var session = _session;
      if (session == null || !session.expiresAt.isAfter(DateTime.now())) {
        session = await _gateway.startSession();
        if (revision != _revision) return;
        _session = session;
      }

      final suggestions = await _gateway.search(session.id, query);
      if (revision != _revision) return;
      _suggestions = suggestions;
      _errorMessage = null;
    } on ApiException catch (error) {
      if (revision != _revision) return;
      if (error.statusCode == 400) _session = null;
      _suggestions = const [];
      _errorMessage = error.message;
    } finally {
      if (revision == _revision) {
        _searching = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
