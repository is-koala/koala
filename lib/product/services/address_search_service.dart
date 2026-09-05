import 'package:flutter/foundation.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

abstract interface class AddressSearchGateway {
  Future<AddressSearchSession> startSession();

  Future<List<AddressSuggestion>> search(String sessionId, String query);

  Future<AddressCandidate> resolve(String sessionId, String candidateId);
}

class AddressSearchService implements AddressSearchGateway {
  AddressSearchService._(this._apiClient);

  static final AddressSearchService _instance = AddressSearchService._(
    ApiClient(),
  );

  factory AddressSearchService() => _instance;

  @visibleForTesting
  factory AddressSearchService.withClient(ApiClient apiClient) {
    return AddressSearchService._(apiClient);
  }

  final ApiClient _apiClient;

  @override
  Future<AddressSearchSession> startSession() {
    return _apiClient.post<AddressSearchSession>(
      ApiPaths.addressSearchSessions,
      parse: (data) =>
          AddressSearchSession.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<List<AddressSuggestion>> search(String sessionId, String query) {
    return _apiClient.get<List<AddressSuggestion>>(
      ApiPaths.addressSuggestions(sessionId),
      queryParameters: {'query': query},
      parse: (data) => data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(AddressSuggestion.fromJson)
                .toList()
          : const [],
    );
  }

  @override
  Future<AddressCandidate> resolve(String sessionId, String candidateId) {
    return _apiClient.post<AddressCandidate>(
      ApiPaths.resolveAddressCandidate(sessionId, candidateId),
      parse: (data) => AddressCandidate.fromJson(data as Map<String, dynamic>),
    );
  }
}
