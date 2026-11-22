import 'package:url_launcher/url_launcher.dart';

typedef LegalUrlLauncher = Future<bool> Function(Uri url, LaunchMode mode);

class LegalDocumentBrowser {
  LegalDocumentBrowser({LegalUrlLauncher? launch})
    : _launch = launch ?? _launchUrl;

  final LegalUrlLauncher _launch;

  /// Yalnız HTTPS güvenilir.
  bool canOpen(String? contentUrl) => _httpsUri(contentUrl) != null;

  Future<bool> open(String? contentUrl) {
    final uri = _httpsUri(contentUrl);
    if (uri == null) return Future.value(false);
    return _launch(uri, LaunchMode.externalApplication);
  }

  static Uri? _httpsUri(String? contentUrl) {
    final value = contentUrl?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  static Future<bool> _launchUrl(Uri url, LaunchMode mode) {
    return launchUrl(url, mode: mode);
  }
}
