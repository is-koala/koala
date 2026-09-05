import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/providers/address_autocomplete_controller.dart';
import 'package:koala/product/services/address_search_service.dart';

class _Gateway implements AddressSearchGateway {
  int sessionCalls = 0;
  final List<String> queries = [];
  final Map<String, Completer<List<AddressSuggestion>>> pending = {};

  @override
  Future<AddressSearchSession> startSession() async {
    sessionCalls++;
    return AddressSearchSession(
      id: 'session-$sessionCalls',
      expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    );
  }

  @override
  Future<List<AddressSuggestion>> search(String sessionId, String query) {
    queries.add(query);
    return pending.putIfAbsent(query, Completer.new).future;
  }

  @override
  Future<AddressCandidate> resolve(String sessionId, String candidateId) {
    throw UnimplementedError();
  }
}

void main() {
  test('iki karaktere kadar ağ isteği oluşturmaz', () async {
    final gateway = _Gateway();
    final controller = AddressAutocompleteController(
      gateway: gateway,
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.queryChanged('Mo');
    await Future<void>.delayed(Duration.zero);

    expect(gateway.sessionCalls, 0);
    expect(gateway.queries, isEmpty);
  });

  test('debounce hızlı yazımı tek sorguya indirir', () async {
    final gateway = _Gateway();
    final controller = AddressAutocompleteController(
      gateway: gateway,
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);

    controller.queryChanged('Mod');
    controller.queryChanged('Moda');
    controller.queryChanged('Moda Caddesi');
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(gateway.queries, ['Moda Caddesi']);
    gateway.pending['Moda Caddesi']!.complete(const []);
  });

  test('geç gelen eski yanıt yeni önerileri ezmez', () async {
    final gateway = _Gateway();
    final controller = AddressAutocompleteController(
      gateway: gateway,
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.queryChanged('Moda');
    await Future<void>.delayed(Duration.zero);
    controller.queryChanged('Moda Caddesi');
    await Future<void>.delayed(Duration.zero);

    gateway.pending['Moda Caddesi']!.complete(const [
      AddressSuggestion(
        id: 'new',
        mainText: 'Moda Caddesi',
        secondaryText: 'Kadıköy',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    gateway.pending['Moda']!.complete(const [
      AddressSuggestion(id: 'old', mainText: 'Moda', secondaryText: 'İstanbul'),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.suggestions.single.id, 'new');
  });
}
