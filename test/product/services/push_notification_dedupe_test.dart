import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/push_notification_dedupe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PushNotificationDedupe dedupe;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 9, 13, 8);
    dedupe = PushNotificationDedupe(
      prefs: await SharedPreferences.getInstance(),
      now: () => now,
    );
  });

  test('aynı notificationId ikinci kez işlenmez', () async {
    expect(await dedupe.claim('ntf-1'), isTrue);
    expect(await dedupe.claim('ntf-1'), isFalse);
  });

  test('süre dolunca aynı id yeniden işlenebilir', () async {
    expect(await dedupe.claim('ntf-1'), isTrue);

    now = now.add(const Duration(days: 7, milliseconds: 1));
    expect(await dedupe.claim('ntf-1'), isTrue);
  });

  test('süre dolmadan kayıt diskte kalır', () async {
    await dedupe.claim('ntf-1');
    now = now.add(const Duration(days: 6, hours: 23));

    final again = PushNotificationDedupe(
      prefs: await SharedPreferences.getInstance(),
      now: () => now,
    );
    expect(await again.claim('ntf-1'), isFalse);
  });
}
