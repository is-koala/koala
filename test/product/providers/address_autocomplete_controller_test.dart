import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/canonical_address.dart';
import 'package:koala/product/providers/address_autocomplete_controller.dart';
import 'package:koala/product/services/address_search_service.dart';

const _debounce = Duration(milliseconds: 20);

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

  @override
  Future<AddressCandidate> reverse(double latitude, double longitude) {
    throw UnimplementedError();
  }
}

// Kontrolcü Timer ile debounce yapıyor; testWidgets'ın sahte saati (pump)
// zamanlayıcıları makine yükünden bağımsız, deterministik ilerletir.
void main() {
  testWidgets('iki karaktere kadar ağ isteği oluşturmaz', (tester) async {
    final gateway = _Gateway();
    final controller = AddressAutocompleteController(
      gateway: gateway,
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.queryChanged('Mo');
    await tester.pump(Duration.zero);

    expect(gateway.sessionCalls, 0);
    expect(gateway.queries, isEmpty);
  });

  testWidgets('debounce hızlı yazımı tek sorguya indirir', (tester) async {
    final gateway = _Gateway();
    final controller = AddressAutocompleteController(
      gateway: gateway,
      debounce: _debounce,
    );
    addTearDown(controller.dispose);

    controller.queryChanged('Mod');
    controller.queryChanged('Moda');
    controller.queryChanged('Moda Caddesi');
    await tester.pump(_debounce - const Duration(milliseconds: 1));
    expect(gateway.queries, isEmpty, reason: 'debounce dolmadı');

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(gateway.queries, ['Moda Caddesi']);
    gateway.pending['Moda Caddesi']!.complete(const []);
    await tester.pump();
  });

  testWidgets('geç gelen eski yanıt yeni önerileri ezmez', (tester) async {
    final gateway = _Gateway();
    final controller = AddressAutocompleteController(
      gateway: gateway,
      debounce: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.queryChanged('Moda');
    await tester.pump(Duration.zero);
    controller.queryChanged('Moda Caddesi');
    await tester.pump(Duration.zero);

    gateway.pending['Moda Caddesi']!.complete(const [
      AddressSuggestion(
        id: 'new',
        mainText: 'Moda Caddesi',
        secondaryText: 'Kadıköy',
      ),
    ]);
    await tester.pump();
    gateway.pending['Moda']!.complete(const [
      AddressSuggestion(id: 'old', mainText: 'Moda', secondaryText: 'İstanbul'),
    ]);
    await tester.pump();

    expect(controller.suggestions.single.id, 'new');
  });
}
