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
  late List<String> conversations;
  late List<({String assignmentId, bool seatDropped})> transports;
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
    conversations = [];
    transports = [];
    sessionReady = true;
    inbox = PushInbox(
      dedupe: dedupe,
      sessionInitialized: () => sessionReady,
      notificationsRoute: () => '/notifications',
      navigate: routes.add,
      onForeground: () async => foreground.add('refresh'),
      onOpened: (id) async => opened.add(id),
      onConversationOpened: (id) async => conversations.add(id),
      onTransportOpened:
          ({required assignmentId, required seatDropped}) async => transports
              .add((assignmentId: assignmentId, seatDropped: seatDropped)),
    );
  });

  Map<String, String> transportPush({
    String event = 'PLAN_UPDATED',
    String? assignmentId = 'asg-1',
    String? notificationId = 'ntf-t1',
  }) => {
    'type': 'TRANSPORT',
    'event': event,
    'jobId': 'job-1',
    'jobAssignmentId': ?assignmentId,
    'notificationId': ?notificationId,
  };

  Map<String, String> messagePush({
    String conversationId = 'conv-1',
    String? messageId = 'msg-1',
    String? notificationId = 'ntf-m1',
  }) => {
    'type': 'MESSAGE',
    'conversationId': conversationId,
    'messageId': ?messageId,
    'notificationId': ?notificationId,
  };

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

  // Backend mesaj push'ını `type=MESSAGE, conversationId, messageId` ile
  // gönderiyor (`ActivityNotificationManager.messageSent`); `notificationId`
  // teslimatta ekleniyor. Bu yük sohbet ekranına gider, bildirim ekranına
  // değil; `IN_APP` satırı olmadığı için okundu işaretlenecek bir şey yok.
  group('sohbet mesajı push\'ı', () {
    test('ön planda hiçbir şey yapmaz: STOMP zaten çizdi', () async {
      await inbox.handleForeground(messagePush());

      expect(foreground, isEmpty);
      expect(routes, isEmpty);
      expect(conversations, isEmpty);
      expect(opened, isEmpty);
    });

    // Ön planda işlenmeyen yük dedupe'a yazılmaz: banner gösteren bir
    // platformda arkasından gelen dokunma hâlâ açılabilmeli.
    test('ön plandan sonra gelen dokunma yine sohbeti açar', () async {
      await inbox.handleForeground(messagePush());
      await inbox.handleOpened(messagePush());

      expect(conversations, ['conv-1']);
    });

    test('dokunma sohbeti açar, bildirim ekranına gitmez', () async {
      await inbox.handleOpened(messagePush());

      expect(conversations, ['conv-1']);
      expect(routes, isEmpty);
      expect(opened, isEmpty);
      expect(foreground, isEmpty);
    });

    // Soğuk açılışta `getInitialMessage` ve `onMessageOpenedApp` aynı yükü
    // iki kez verebiliyor; anahtar `messageId`.
    test('aynı mesajın ikinci dokunması yok sayılır', () async {
      await inbox.handleOpened(messagePush());
      await inbox.handleOpened(messagePush(notificationId: 'ntf-m1-again'));

      expect(conversations, ['conv-1']);
    });

    test('messageId yoksa notificationId ile dedupe edilir', () async {
      await inbox.handleOpened(messagePush(messageId: null));
      await inbox.handleOpened(messagePush(messageId: null));

      expect(conversations, ['conv-1']);
    });

    test('oturum okunmadan gelen dokunma bekler, sonra sohbeti açar', () async {
      sessionReady = false;
      await inbox.handleOpened(messagePush());
      expect(conversations, isEmpty);

      sessionReady = true;
      await inbox.flush();

      expect(conversations, ['conv-1']);
      expect(routes, isEmpty);
    });

    test(
      'conversationId olmayan MESSAGE sıradan bildirim gibi işlenir',
      () async {
        await inbox.handleOpened({
          'type': 'MESSAGE',
          'notificationId': 'ntf-x',
        });

        expect(conversations, isEmpty);
        expect(routes, ['/notifications']);
        expect(opened, ['ntf-x']);
      },
    );
  });

  // Backend ulaşım push'unu `type=TRANSPORT, event, jobId, jobAssignmentId`
  // ile gönderiyor (`TransportManager.notifyWorker`); `IN_APP` satırı da var,
  // o yüzden ön planda liste tazelenir ve dokunma okundu işaretlenir. Hedef
  // bildirim ekranı değil iş detayı (is-koala/koala#197).
  group('ulaşım push\'ı', () {
    test('ön planda sıradan bildirim gibi listeyi tazeler', () async {
      await inbox.handleForeground(transportPush());

      expect(foreground, ['refresh']);
      expect(transports, isEmpty);
      expect(routes, isEmpty);
    });

    test('dokunma iş detayını açar ve okundu işaretler', () async {
      await inbox.handleOpened(transportPush());

      expect(transports, [(assignmentId: 'asg-1', seatDropped: false)]);
      expect(opened, ['ntf-t1']);
      expect(routes, isEmpty);
    });

    test('SEAT_DROPPED olayı yeniden seçim bağlamıyla açılır', () async {
      await inbox.handleOpened(transportPush(event: 'SEAT_DROPPED'));

      expect(transports, [(assignmentId: 'asg-1', seatDropped: true)]);
    });

    test('aynı bildirimin ikinci dokunması yok sayılır', () async {
      await inbox.handleOpened(transportPush());
      await inbox.handleOpened(transportPush());

      expect(transports, hasLength(1));
    });

    test('oturum okunmadan gelen dokunma bekler, sonra detayı açar', () async {
      sessionReady = false;
      await inbox.handleOpened(transportPush());
      expect(transports, isEmpty);

      sessionReady = true;
      await inbox.flush();

      expect(transports, hasLength(1));
    });

    test('jobAssignmentId olmayan TRANSPORT sıradan bildirim gibi', () async {
      await inbox.handleOpened(transportPush(assignmentId: null));

      expect(transports, isEmpty);
      expect(routes, ['/notifications']);
      expect(opened, ['ntf-t1']);
    });

    test('açıcı verilmemişse bildirim ekranına düşer', () async {
      final plain = PushInbox(
        dedupe: dedupe,
        sessionInitialized: () => true,
        notificationsRoute: () => '/business/notifications',
        navigate: routes.add,
        onForeground: () async {},
        onOpened: (id) async => opened.add(id),
        onConversationOpened: (_) async {},
      );

      await plain.handleOpened(transportPush());

      expect(routes, ['/business/notifications']);
      expect(opened, ['ntf-t1']);
    });
  });
}
