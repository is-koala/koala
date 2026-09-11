import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/services/auth_service.dart';
import 'package:koala/product/network/api_paths.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/network/token_storage.dart';
import 'package:koala/product/services/push_token_lifecycle.dart';
import 'package:koala/product/services/push_token_service.dart';
import 'package:koala/product/services/push_token_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late SessionManager session;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    storage = TokenStorage.withStorage(
      const FlutterSecureStorage(),
      apiOrigin: 'https://test.local',
    );
    session = SessionManager.withTokenStorage(storage);
  });

  tearDown(() => session.dispose());

  test('oturum yokken gelen token bekler, girişten sonra yazılır', () async {
    final api = FakeApi(
      handler: (request) {
        if (request.path == ApiPaths.currentUserPushToken) {
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true},
          );
        }
        throw StateError('beklenmeyen ${request.path}');
      },
    );
    final source = FakePushTokenSource(token: 'pending-token');
    final lifecycle = PushTokenLifecycle.withDependencies(
      service: PushTokenService.withClient(api.client),
      source: source,
      session: session,
    );

    await lifecycle.syncQuietly();
    expect(api.requests, isEmpty);

    await session.start(
      accessToken: 'access',
      refreshToken: 'refresh',
      isEmployer: false,
    );
    await lifecycle.syncQuietly();

    expect(api.requests.single.method, 'PUT');
    expect(api.requests.single.data, {'pushToken': 'pending-token'});
  });

  test('oturum açıkken token yenilenince yeniden yazılır', () async {
    final refreshes = StreamController<String>.broadcast();
    addTearDown(refreshes.close);
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    await session.start(
      accessToken: 'access',
      refreshToken: 'refresh',
      isEmployer: false,
    );
    final lifecycle = PushTokenLifecycle.withDependencies(
      service: PushTokenService.withClient(api.client),
      source: FakePushTokenSource(token: 'first', refreshes: refreshes.stream),
      session: session,
    );
    lifecycle.listen();

    refreshes.add('rotated-token');
    await pumpEventQueue(times: 20);

    expect(api.requests.single.data, {'pushToken': 'rotated-token'});
  });

  test('yazım 404 olsa bile sessizce geçer', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 404,
        body: {
          'success': false,
          'errorCode': 'DEVICE_NOT_FOUND',
          'errorCategory': 'RESOURCE_NOT_FOUND',
          'message': 'Cihaz bulunamadı',
        },
      ),
    );
    await session.start(
      accessToken: 'access',
      refreshToken: 'refresh',
      isEmployer: false,
    );

    await PushTokenLifecycle.withDependencies(
      service: PushTokenService.withClient(api.client),
      source: FakePushTokenSource(token: 'token'),
      session: session,
    ).syncQuietly();

    expect(api.requests, hasLength(1));
  });

  test('çıkış önce token siler, DELETE düşse bile logout tamamlanır', () async {
    final api = FakeApi(
      handler: (request) {
        if (request.path == ApiPaths.currentUserPushToken) {
          if (request.method == 'PUT') {
            return const FakeApiResponse(
              statusCode: 200,
              body: {'success': true},
            );
          }
          return const FakeApiResponse(
            statusCode: 500,
            body: {
              'success': false,
              'errorCode': 'UNEXPECTED',
              'errorCategory': 'UNEXPECTED',
              'message': 'silinemedi',
            },
          );
        }
        if (request.path == ApiPaths.logout) {
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true},
          );
        }
        if (request.path == ApiPaths.login) {
          return const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {'token': 'access', 'refreshToken': 'refresh'},
            },
          );
        }
        if (request.path == ApiPaths.currentUser) {
          return const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'id': 'user-id',
                'email': 'hesap@example.com',
                'isEmployer': false,
              },
            },
          );
        }
        throw StateError('beklenmeyen ${request.path}');
      },
    );
    final lifecycle = PushTokenLifecycle.withDependencies(
      service: PushTokenService.withClient(api.client),
      source: FakePushTokenSource(token: 'device-token'),
      session: session,
    );
    final auth = AuthService.withClient(
      api.client,
      sessionManager: session,
      pushTokens: lifecycle,
    );

    await auth.login(email: 'hesap@example.com', password: 'TestPassword1');
    api.requests.clear();

    await auth.logout();

    expect(api.requests.map((request) => request.path), [
      ApiPaths.currentUserPushToken,
      ApiPaths.logout,
    ]);
    expect(api.requests.first.method, 'DELETE');
    expect(session.isLoggedIn, isFalse);
  });

  test('kaynak token vermezse ağ çağrısı yoktur', () async {
    final api = FakeApi(
      handler: (_) =>
          const FakeApiResponse(statusCode: 200, body: {'success': true}),
    );
    await session.start(
      accessToken: 'access',
      refreshToken: 'refresh',
      isEmployer: false,
    );

    await PushTokenLifecycle.withDependencies(
      service: PushTokenService.withClient(api.client),
      source: const UnavailablePushTokenSource(),
      session: session,
    ).syncQuietly();

    expect(api.requests, isEmpty);
  });
}
