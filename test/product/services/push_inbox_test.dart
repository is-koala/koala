import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/push_inbox.dart';
import 'package:koala/product/services/push_notification_dedupe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PushNotificationDedupe dedupe;
  late List<String> foreground;
  late List<String> opened;
  late List<String> routes;
  late bool sessionReady;
  late PushInbox inbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dedupe = PushNotificationDedupe(
      prefs: await SharedPreferences.getInstance(),
      now: () => DateTime.utc(2026, 9, 13, 8),
    );
    foreground = [];
    opened = [];
    routes = [];
    sessionReady = true;
    inbox = PushInbox(
      dedupe: dedupe,
      sessionInitialized: () => sessionReady,
      notificationsRoute: () => '/notifications',
      navigate: routes.add,
      onForeground: () async => foreground.add('refresh'),
      onOpened: (id) async => opened.add(id),
    );
  });

  test('ön plan bildirimi listeyi tazeler, gezinmez', () async {
    await inbox.handleForeground({'notificationId': 'ntf-1'});

    expect(foreground, ['refresh']);
    expect(routes, isEmpty);
    expect(opened, isEmpty);
  });

  test('notificationId olmayan ön plan yine listeyi tazeler', () async {
    await inbox.handleForeground({'other': 'x'});

    expect(foreground, ['refresh']);
    expect(routes, isEmpty);
  });

  test('aynı ön plan bildirimi ikinci teslimatta işlenmez', () async {
    await inbox.handleForeground({'notificationId': 'ntf-1'});
    await inbox.handleForeground({'notificationId': 'ntf-1'});

    expect(foreground, ['refresh']);
  });

  test('dokunma bildirim ekranına gider ve okundu işaretler', () async {
    await inbox.handleOpened({'notificationId': 'ntf-9'});

    expect(routes, ['/notifications']);
    expect(opened, ['ntf-9']);
  });

  test('oturum okunmadan gelen dokunma bekler, sonra bir kez açılır', () async {
    sessionReady = false;
    await inbox.handleOpened({'notificationId': 'ntf-wait'});
    expect(routes, isEmpty);

    sessionReady = true;
    await inbox.flush();

    expect(routes, ['/notifications']);
    expect(opened, ['ntf-wait']);
  });

  test('notificationId olmayan dokunma yok sayılır', () async {
    await inbox.handleOpened({});
    await inbox.handleOpened({'other': 'x'});

    expect(foreground, isEmpty);
    expect(routes, isEmpty);
    expect(opened, isEmpty);
  });
}
