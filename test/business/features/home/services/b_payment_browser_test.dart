import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/services/b_payment_browser.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('Iyzico sayfası desteklenen uygulama içi tarayıcıda açılır', () async {
    LaunchMode? checkedMode;
    LaunchMode? launchedMode;
    Uri? launchedUrl;
    final browser = BPaymentBrowser(
      supportsMode: (mode) async {
        checkedMode = mode;
        return true;
      },
      launch: (url, mode) async {
        launchedUrl = url;
        launchedMode = mode;
        return true;
      },
    );
    final url = Uri.parse(
      'https://sandbox-cpp.iyzipay.com?token=token&lang=tr',
    );

    expect(await browser.open(url), isTrue);
    expect(checkedMode, LaunchMode.inAppBrowserView);
    expect(launchedMode, LaunchMode.inAppBrowserView);
    expect(launchedUrl, url);
  });

  test('uygulama içi tarayıcı yoksa harici tarayıcıya düşmez', () async {
    var launchCount = 0;
    final browser = BPaymentBrowser(
      supportsMode: (_) async => false,
      launch: (_, _) async {
        launchCount++;
        return true;
      },
    );

    final opened = await browser.open(
      Uri.parse('https://sandbox-api.iyzipay.com/checkoutform/token'),
    );

    expect(opened, isFalse);
    expect(launchCount, 0);
  });

  test('HTTP ve benzer Iyzico hostları açılmadan reddedilir', () async {
    var supportCount = 0;
    var launchCount = 0;
    final browser = BPaymentBrowser(
      supportsMode: (_) async {
        supportCount++;
        return true;
      },
      launch: (_, _) async {
        launchCount++;
        return true;
      },
    );

    for (final value in [
      'http://sandbox-cpp.iyzipay.com/?token=token',
      'https://sandbox-cpp.iyzipay.com.attacker.example/?token=token',
      'https://user:pass@sandbox-cpp.iyzipay.com/?token=token',
      'https://sandbox-cpp.iyzipay.com:8443/?token=token',
    ]) {
      expect(await browser.open(Uri.parse(value)), isFalse);
    }

    expect(supportCount, 0);
    expect(launchCount, 0);
  });
}
