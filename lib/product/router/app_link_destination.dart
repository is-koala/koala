/// Native uygulama linklerini go_router rotalarına çeviren saf sınır.
class AppLinkDestination {
  const AppLinkDestination._();

  static String? routeFor(Uri uri, {required String appScheme}) {
    if (uri.scheme != appScheme ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return null;
    }

    if (uri.host == 'hesap-dogrula' ||
        uri.host == 'sifre-belirle' ||
        uri.host == 'complete-registration') {
      final token = _parameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/auth/register-type/register/creating-password',
        queryParameters: {'token': token},
      ).toString();
    }

    if (uri.host == 'sifre-sifirla' || uri.host == 'reset-password') {
      final token = _parameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/reset-password',
        queryParameters: {'token': token},
      ).toString();
    }

    if (uri.host == 'eposta-onayla') {
      final token = _parameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/email-verification',
        queryParameters: {'token': token},
      ).toString();
    }

    if (uri.host == 'payment-result') {
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

  static String? _parameter(Uri uri, String name) {
    final values = uri.queryParametersAll[name];
    if (values == null || values.length != 1 || values.single.trim().isEmpty) {
      return null;
    }
    return values.single;
  }
}
