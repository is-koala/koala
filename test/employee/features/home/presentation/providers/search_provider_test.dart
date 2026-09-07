import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/presentation/providers/search_provider.dart';

void main() {
  late SearchProvider provider;
  late int notifications;

  setUp(() {
    provider = SearchProvider();
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  test('başlangıçta arama kipi kapalı', () {
    expect(provider.isSearching, isFalse);
  });

  test('startSearching kipi açar ve bildirir', () {
    provider.startSearching();

    expect(provider.isSearching, isTrue);
    expect(notifications, 1);
  });

  test('stopSearching kipi kapatır ve bildirir', () {
    provider.startSearching();
    provider.stopSearching();

    expect(provider.isSearching, isFalse);
    expect(notifications, 2);
  });
}
