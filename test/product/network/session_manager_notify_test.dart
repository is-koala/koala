import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionManager session;
  late int notifications;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    session = SessionManager.withTokenStorage(
      TokenStorage.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://test.local',
      ),
    );
    notifications = 0;
    session.addListener(() => notifications++);
  });

  tearDown(() => session.dispose());

  group('Oturum bildirimleri', () {
    // Oturum açan yollar bilerek sessiz: router muhafızını akışın ortasında
    // tetiklemek kullanıcıyı adımın sonunu görmeden ana sayfaya atıyor ve
    // kayıt sonrası şirket bilgileri adımı bu yüzden atlanıyordu. Giriş ve
    // kayıt akışları yönlendirmeyi kendi `context.go` çağrılarıyla yapıyor.
    test('start dinleyicileri uyarmaz', () async {
      await session.start(
        accessToken: 'a',
        refreshToken: 'r',
        isEmployer: true,
      );
      expect(notifications, 0);
      expect(session.isLoggedIn, isTrue);
    });

    test('startWithVerifiedUserType dinleyicileri uyarmaz', () async {
      await session.startWithVerifiedUserType(
        accessToken: 'a',
        refreshToken: 'r',
        verifyUserType: () async => false,
      );
      expect(notifications, 0);
      expect(session.isLoggedIn, isTrue);
    });

    // Çıkışta bildirim şart: muhafız kullanıcıyı `/auth`'a atıyor.
    test('end dinleyicileri uyarır', () async {
      await session.end();
      expect(notifications, greaterThan(0));
    });
  });
}
