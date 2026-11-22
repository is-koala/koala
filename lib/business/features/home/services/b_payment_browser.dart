import 'package:url_launcher/url_launcher.dart';

typedef PaymentLaunchModeSupport = Future<bool> Function(LaunchMode mode);
typedef PaymentUrlLauncher = Future<bool> Function(Uri url, LaunchMode mode);

/// Iyzico ödeme sayfasını uygulama içinde açar.
class BPaymentBrowser {
  BPaymentBrowser({
    PaymentLaunchModeSupport? supportsMode,
    PaymentUrlLauncher? launch,
  }) : _supportsMode = supportsMode ?? supportsLaunchMode,
       _launch = launch ?? _launchUrl;

  static const Set<String> _allowedHosts = {
    'api.iyzipay.com',
    'cpp.iyzipay.com',
    'sandbox-api.iyzipay.com',
    'sandbox-cpp.iyzipay.com',
  };

  final PaymentLaunchModeSupport _supportsMode;
  final PaymentUrlLauncher _launch;

  /// Yalnız Iyzico'nun HTTPS sayfasını Custom Tabs / SFSafariViewController'da
  /// açar; desteklenmiyorsa harici tarayıcıya düşmek yerine `false`.
  Future<bool> open(Uri url) async {
    if (!_isAllowed(url)) return false;
    if (!await _supportsMode(LaunchMode.inAppBrowserView)) return false;
    return _launch(url, LaunchMode.inAppBrowserView);
  }

  static bool _isAllowed(Uri url) {
    return url.scheme == 'https' &&
        _allowedHosts.contains(url.host) &&
        url.userInfo.isEmpty &&
        !url.hasPort &&
        url.fragment.isEmpty;
  }

  static Future<bool> _launchUrl(Uri url, LaunchMode mode) {
    return launchUrl(
      url,
      mode: mode,
      browserConfiguration: const BrowserConfiguration(showTitle: true),
    );
  }
}
