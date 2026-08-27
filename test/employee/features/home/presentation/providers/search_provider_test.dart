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

  test('başlangıçta boş ve kapalı', () {
    expect(provider.query, isEmpty);
    expect(provider.isSearching, isFalse);
  });

  test('setQuery sorguyu yazar ve bildirir', () {
    provider.setQuery('barista');

    expect(provider.query, 'barista');
    expect(notifications, 1);
  });

  test('startSearching arama kipini açar, sorguya dokunmaz', () {
    provider.setQuery('garson');
    provider.startSearching();

    expect(provider.isSearching, isTrue);
    expect(provider.query, 'garson');
  });

  // stopSearching hem kipi kapatıyor hem sorguyu siliyor: arama kapanınca
  // liste filtresiz haline dönsün diye.
  test('stopSearching kipi kapatır ve sorguyu temizler', () {
    provider.setQuery('garson');
    provider.startSearching();
    provider.stopSearching();

    expect(provider.isSearching, isFalse);
    expect(provider.query, isEmpty);
  });

  test('clearQuery sorguyu siler ama kipi açık bırakır', () {
    provider.setQuery('garson');
    provider.startSearching();
    provider.clearQuery();

    expect(provider.query, isEmpty);
    expect(provider.isSearching, isTrue);
  });

  test('boş sorgu da bildirim üretir', () {
    provider.setQuery('');
    expect(notifications, 1);
  });
}
