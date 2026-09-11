import 'package:flutter/foundation.dart';

/// Push token'ının nereden geldiği.
///
/// #29 FCM/APNs kurulumu bitene kadar üretim [UnavailablePushTokenSource]
/// kullanır: token yoktur, yenileme akışı boştur. Yaşam döngüsü (#30) yine
/// de yazılır; kaynak bağlanınca aynı kancalar gerçek token'ı taşır.
abstract class PushTokenSource {
  Future<String?> currentToken();

  Stream<String> get onRefresh;
}

/// Platform kurulumu yokken kullanılan kaynak.
class UnavailablePushTokenSource implements PushTokenSource {
  const UnavailablePushTokenSource();

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get onRefresh => const Stream<String>.empty();
}

/// Testte enjekte edilen kaynak.
///
/// Yenileme akışındaki son değer `currentToken` olur; gerçek FCM de
/// `getToken` ile son olayı hizalar.
@visibleForTesting
class FakePushTokenSource implements PushTokenSource {
  FakePushTokenSource({this.token, Stream<String>? refreshes})
    : _refreshes = refreshes ?? const Stream<String>.empty();

  String? token;
  final Stream<String> _refreshes;

  @override
  Future<String?> currentToken() async => token;

  @override
  Stream<String> get onRefresh => _refreshes.map((value) {
    token = value;
    return value;
  });
}
