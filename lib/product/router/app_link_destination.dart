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

    if (uri.host == 'complete-registration') {
      final token = _singleParameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/auth/register-type/register/creating-password',
        queryParameters: {'token': token},
      ).toString();
    }

    if (uri.host == 'reset-password') {
      final token = _singleParameter(uri, 'token');
      if (token == null) return null;
      return Uri(
        path: '/reset-password',
        queryParameters: {'token': token},
      ).toString();
    }

    if (uri.host == 'payment-result') {
      if (uri.queryParametersAll.length != 2) return null;
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

  static String? _singleParameter(Uri uri, String name) {
    if (uri.queryParametersAll.length != 1) return null;
    return _parameter(uri, name);
  }

  static String? _parameter(Uri uri, String name) {
    final values = uri.queryParametersAll[name];
    if (values == null || values.length != 1 || values.single.trim().isEmpty) {
      return null;
    }
    return values.single;
  }
}
