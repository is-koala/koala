import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Anahtarlık silmenin cihazda başarısız olduğu durumu taklit eder.
/// `-34018 errSecMissingEntitlement` imzasız simülatör build'inde tam olarak
/// böyle davranıyordu.
class _ClearFailsTokenStorage extends TokenStorage {
  _ClearFailsTokenStorage()
    : super.withStorage(
        const FlutterSecureStorage(),
        apiOrigin: 'https://test.local',
      );

  @override
  Future<void> clear() async => throw StateError('anahtarlık silinemedi');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('temizlik hatası asıl hatanın yerine geçmez', () async {
    final session = SessionManager.withTokenStorage(_ClearFailsTokenStorage());
    addTearDown(session.dispose);

    await expectLater(
      session.startWithVerifiedUserType(
        accessToken: 'a',
        refreshToken: 'r',
        verifyUserType: () async => throw const FormatException('asıl hata'),
      ),
      // Kullanıcı ve log, oturumun neden açılmadığını anlatan asıl hatayı
      // görmeli; temizlik sırasındaki ikincil hata onu gizlememeli.
      throwsA(isA<FormatException>()),
    );
  });
}
