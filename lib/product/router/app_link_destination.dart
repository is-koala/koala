/// Özel şema ve doğrulanmış HTTPS linklerini go_router rotalarına çeviren sınır.
class AppLinkDestination {
  const AppLinkDestination._();

  /// Android manifest'in ve web `appLinkPaths` listesinin sahiplendiği HTTPS
  /// yol önekleri. `test/product/router/platform_link_configuration_test.dart`
  /// flavor manifestlerini bu listeyle karşılaştırır; buraya eklenen yol
  /// manifest'e de girmeden bağlantı uygulamaya ulaşmaz.
  static const List<String> httpsPathPrefixes = [
    '/hesap-dogrula',
    '/sifre-belirle',
    '/sifre-sifirla',
    '/eposta-onayla',
    '/payment/result',
    '/davet',
    // Paylaşılan ilan: `/is-ilanlari/<jobId>`. Sondaki `/` liste sayfasını
    // (`/is-ilanlari`) dışarıda bırakıyor; liste web'de kalıyor.
    '/is-ilanlari/',
  ];

  /// [uri]'yi uygulama rotasına çevirir; sözleşmeye uymayan bağlantıda `null`.
  ///
  /// [appScheme] çalışan flavor'ın özel şeması, [webHosts] aynı flavor'ın
  /// `WEB_HOSTS` yapılandırmasından gelen doğrulanmış HTTPS hostlarıdır.
  static String? routeFor(
    Uri uri, {
    required String appScheme,
    required Set<String> webHosts,
  }) {
    final link = _resolve(uri, appScheme: appScheme, webHosts: webHosts);
    if (link == null) return null;
    final destination = link.destination;

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

    if (destination == 'job') {
      // HTTPS'te kimlik web'in `/is-ilanlari/<id>` yolundan, özel şemada
      // (`koala://job?id=`) sorgu alanından okunur.
      final id = link.pathId ?? _parameter(uri, 'id');
      if (id == null) return null;
      return Uri(path: '/shared-job', queryParameters: {'id': id}).toString();
    }

    if (destination == 'board') {
      // Biniş QR'ı (is-koala/koala#217): `{şema}://board?t=<token>`. Token
      // olduğu gibi taşınır; türünü ve kimliğini sayfa okur, imzayı sunucu
      // doğrular. Yalnız özel şemada — HTTPS karşılığı yok.
      final token = _parameter(uri, 't');
      if (token == null || link.pathId != null) return null;
      return Uri(
        path: '/boarding-link',
        queryParameters: {'t': token},
      ).toString();
    }

    if (destination == 'company-invitation') {
      // HTTPS'te kimlik web'in `/davet/<id>` yolundan okunur ve sorgu alanı
      // yok sayılır; özel şemada yol boş olduğu için `id` sorgu alanındadır.
      final id = link.pathId ?? _parameter(uri, 'id');
      if (id == null) return null;
      return Uri(
        path: '/company-invitation',
        queryParameters: {'id': id},
      ).toString();
    }

    return null;
  }

  static _ResolvedLink? _resolve(
    Uri uri, {
    required String appScheme,
    required Set<String> webHosts,
  }) {
    if (uri.userInfo.isNotEmpty || uri.hasPort || uri.fragment.isNotEmpty) {
      return null;
    }

    if (uri.scheme == appScheme) {
      return uri.path.isEmpty ? _ResolvedLink(uri.host) : null;
    }

    if (uri.scheme != 'https' ||
        !webHosts.contains(uri.host) ||
        uri.pathSegments.isEmpty) {
      return null;
    }

    final segments = uri.pathSegments;

    if (segments.length == 2 &&
        segments[0] == 'payment' &&
        segments[1] == 'result') {
      return const _ResolvedLink('payment-result');
    }

    if (segments.length == 2 &&
        segments[0] == 'davet' &&
        segments[1].trim().isNotEmpty) {
      return _ResolvedLink('company-invitation', pathId: segments[1]);
    }

    if (segments.length == 2 &&
        segments[0] == 'is-ilanlari' &&
        segments[1].trim().isNotEmpty) {
      return _ResolvedLink('job', pathId: segments[1]);
    }

    if (segments.length == 1 && _httpsDestinations.contains(segments.single)) {
      return _ResolvedLink(segments.single);
    }

    return null;
  }

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

/// Doğrulanmış bağlantının kanonik hedefi ve yoldan okunan kimlik (davet ya
/// da ilan).
class _ResolvedLink {
  const _ResolvedLink(this.destination, {this.pathId});

  final String destination;
  final String? pathId;
}
