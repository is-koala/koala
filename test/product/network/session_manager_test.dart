import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      SessionManager.isLoggedInKey: true,
      SessionManager.userTypeKey: SessionManager.businessType,
      SessionManager.seenOnboardingKey: true,
    });
    SessionManager().resetForTest();
  });

  test('aynı API oturumu yeniden yüklenir ve çıkışta temizlenir', () async {
    final session = SessionManager();
    await session.start(
      accessToken: 'access',
      refreshToken: 'refresh',
      isEmployer: false,
    );
    session.resetForTest();

    await session.load();
    expect(session.isLoggedIn, isTrue);
    expect(session.userType, SessionManager.employeeType);

    await session.end();
    expect(session.isLoggedIn, isFalse);
    expect(session.userType, isNull);
    expect(session.seenOnboarding, isTrue);
    expect(await TokenStorage().readAccessToken(), isNull);
    expect(await TokenStorage().readRefreshToken(), isNull);
  });

  test('başka API oturumu mevcut hedefte giriş yapılmış sayılmaz', () async {
    final otherApi = TokenStorage.withStorage(
      const FlutterSecureStorage(),
      apiOrigin: 'https://previous.example.test',
    );
    await otherApi.save(accessToken: 'old-access', refreshToken: 'old-refresh');

    final session = SessionManager();
    await session.load();

    expect(session.isLoggedIn, isFalse);
    expect(session.userType, isNull);
    expect(session.seenOnboarding, isTrue);
    expect(session.isInitialized, isTrue);
  });

  test(
    'API değişip geri dönüldüğünde her hesabın kendi rolü korunur',
    () async {
      final firstTokens = TokenStorage.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://first.example.test',
      );
      final secondTokens = TokenStorage.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://second.example.test',
      );
      final first = SessionManager.withTokenStorage(firstTokens);
      final second = SessionManager.withTokenStorage(secondTokens);
      await first.start(
        accessToken: 'employee-access',
        refreshToken: 'employee-refresh',
        isEmployer: false,
      );
      await second.start(
        accessToken: 'employer-access',
        refreshToken: 'employer-refresh',
        isEmployer: true,
      );
      first.resetForTest();

      await first.load();
      expect(first.isLoggedIn, isTrue);
      expect(first.userType, SessionManager.employeeType);
      expect(await firstTokens.readAccessToken(), 'employee-access');

      await first.updateUserType(isEmployer: true);
      await first.end();
      second.resetForTest();
      await second.load();
      expect(second.isLoggedIn, isTrue);
      expect(second.userType, SessionManager.businessType);
      expect(await secondTokens.readAccessToken(), 'employer-access');
    },
  );
}
