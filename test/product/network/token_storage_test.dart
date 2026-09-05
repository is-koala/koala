import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'hedefi belli olmayan eski tokenlar yeni API oturumu sayılmaz',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'koala_access_token': 'legacy-access',
        'koala_refresh_token': 'legacy-refresh',
      });

      expect(await TokenStorage().readAccessToken(), isNull);
      expect(await TokenStorage().readRefreshToken(), isNull);
    },
  );

  test('yenileme ve çıkış yalnız ilgili API tokenlarını değiştirir', () async {
    final first = TokenStorage.withStorage(
      const FlutterSecureStorage(),
      apiOrigin: 'https://first.example.test',
    );
    final second = TokenStorage.withStorage(
      const FlutterSecureStorage(),
      apiOrigin: 'https://second.example.test',
    );
    final expiry = DateTime.utc(2026, 10, 5);
    await first.save(
      accessToken: 'first-access',
      refreshToken: 'first-refresh',
      refreshExpiresAt: expiry,
    );
    await second.save(
      accessToken: 'other-access',
      refreshToken: 'other-refresh',
    );

    await first.saveAccessToken('renewed-access');
    expect(await first.readAccessToken(), 'renewed-access');
    expect(await first.readRefreshToken(), 'first-refresh');
    expect(await first.readRefreshExpiresAt(), expiry);

    await first.clear();
    expect(await first.readAccessToken(), isNull);
    expect(await first.readRefreshToken(), isNull);
    expect(await first.readRefreshExpiresAt(), isNull);
    expect(await second.readAccessToken(), 'other-access');
  });

  test('bir API oturumunun tokenları başka API hedefine taşınmaz', () async {
    final first = TokenStorage.withStorage(
      const FlutterSecureStorage(),
      apiOrigin: 'https://first.example.test',
    );
    final second = TokenStorage.withStorage(
      const FlutterSecureStorage(),
      apiOrigin: 'https://second.example.test',
    );
    await first.save(
      accessToken: 'first-access',
      refreshToken: 'first-refresh',
    );

    expect(await second.readAccessToken(), isNull);
    expect(await second.readRefreshToken(), isNull);
    expect(await first.readAccessToken(), 'first-access');
  });
}
