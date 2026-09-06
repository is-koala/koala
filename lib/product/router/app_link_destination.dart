/// Özel şema ve doğrulanmış HTTPS linklerini go_router rotalarına çeviren sınır.
class AppLinkDestination {
  const AppLinkDestination._();

  static String? routeFor(Uri uri, {required String appScheme}) {
    final destination = _destination(uri, appScheme: appScheme);
    if (destination == null) return null;

    if (destination == 'hesap-dogrula' ||
        destination == 'sifre-belirle' ||
        destination == 'complete-registration') {
      final token = _parameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/auth/register-type/register/creating-password',
        queryParameters: {'token': token},
      ).toString();
    }

    if (destination == 'sifre-sifirla' || destination == 'reset-password') {
      final token = _parameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/reset-password',
        queryParameters: {'token': token},
      ).toString();
    }

    if (destination == 'eposta-onayla') {
      final token = _parameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/email-verification',
        queryParameters: {'token': token},
      ).toString();
    }

    if (destination == 'payment-result') {
      final status = _parameter(uri, 'status');
      final assignmentId = _parameter(uri, 'assignmentId');
      if (status == null || assignmentId == null) return null;
      return Uri(
        path: '/payment-result',
        queryParameters: {'status': status, 'assignmentId': assignmentId},
      ).toString();
    }

    return null;
  }

  static String? _destination(Uri uri, {required String appScheme}) {
    if (uri.userInfo.isNotEmpty || uri.hasPort || uri.fragment.isNotEmpty) {
      return null;
    }

    if (uri.scheme == appScheme) {
      return uri.path.isEmpty ? uri.host : null;
    }

    if (uri.scheme != 'https' ||
        !_httpsHosts(appScheme).contains(uri.host) ||
        uri.pathSegments.isEmpty) {
      return null;
    }

    if (uri.pathSegments.length == 2 &&
        uri.pathSegments[0] == 'payment' &&
        uri.pathSegments[1] == 'result') {
      return 'payment-result';
    }

    if (uri.pathSegments.length == 1 &&
        _httpsDestinations.contains(uri.pathSegments.single)) {
      return uri.pathSegments.single;
    }

    return null;
  }

  static Set<String> _httpsHosts(String appScheme) => switch (appScheme) {
    'koala' => const {'iskoala.com', 'www.iskoala.com'},
    'koala-staging' => const {'staging.iskoala.com'},
    _ => const {},
  };

  static const Set<String> _httpsDestinations = {
    'hesap-dogrula',
    'sifre-belirle',
    'sifre-sifirla',
    'eposta-onayla',
  };

  static String? _parameter(Uri uri, String name) {
    final values = uri.queryParametersAll[name];
    if (values == null || values.length != 1 || values.single.trim().isEmpty) {
      return null;
    }
    return values.single;
  }
}
