import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/firebase_messaging_push_token_source.dart';
import 'package:koala/product/services/push_token_source.dart';

void main() {
  test('FakePushTokenSource yenilemede currentToken ile hizalanır', () async {
    final refreshes = StreamController<String>.broadcast();
    addTearDown(refreshes.close);
    final source = FakePushTokenSource(
      token: 'eski',
      refreshes: refreshes.stream,
    );

    expect(await source.currentToken(), 'eski');

    final received = source.onRefresh.first;
    refreshes.add('yeni-token');
    expect(await received, 'yeni-token');
    expect(await source.currentToken(), 'yeni-token');
  });

  test('UnavailablePushTokenSource token ve yenileme vermez', () async {
    const source = UnavailablePushTokenSource();

    expect(await source.currentToken(), isNull);
    expect(await source.onRefresh.isEmpty, isTrue);
  });

  test('reddedilen ya da sorulmamış izinde token yazılmaz', () {
    expect(isPushDeliveryAllowed(AuthorizationStatus.denied), isFalse);
    expect(isPushDeliveryAllowed(AuthorizationStatus.notDetermined), isFalse);
    expect(isPushDeliveryAllowed(AuthorizationStatus.authorized), isTrue);
    expect(isPushDeliveryAllowed(AuthorizationStatus.provisional), isTrue);
  });
}
