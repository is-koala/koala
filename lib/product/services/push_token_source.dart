import 'package:flutter/foundation.dart';

/// Push token kaynağı. Firebase kalkana kadar [UnavailablePushTokenSource];
/// splash sonra FCM kaynağını bağlar.
abstract class PushTokenSource {
  Future<String?> currentToken();

  Stream<String> get onRefresh;
}

class UnavailablePushTokenSource implements PushTokenSource {
  const UnavailablePushTokenSource();

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get onRefresh => const Stream<String>.empty();
}

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
