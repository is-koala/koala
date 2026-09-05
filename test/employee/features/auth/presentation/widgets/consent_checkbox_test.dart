import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/widgets/consent_checkbox.dart';
import 'package:koala/employee/features/auth/services/legal_document_browser.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'sözleşme bağlantısı kutuyu değiştirmeden harici tarayıcıda açılır: '
      '$brightness',
      (tester) async {
        final openedUrls = <Uri>[];
        final openedModes = <LaunchMode>[];
        final changedValues = <bool>[];
        final browser = LegalDocumentBrowser(
          launch: (url, mode) async {
            openedUrls.add(url);
            openedModes.add(mode);
            return true;
          },
        );

        await pumpInApp(
          tester,
          ConsentCheckbox(
            label: "Kullanım Koşulları'nı okudum, kabul ediyorum.",
            linkText: 'Kullanım Koşulları',
            contentUrl: 'https://iskoala.com/yasal/kullanim-kosullari',
            legalBrowser: browser,
            value: false,
            onChanged: changedValues.add,
          ),
          brightness: brightness,
        );

        await tester.tap(find.text('Kullanım Koşulları'));
        await tester.pump();

        expect(openedUrls, [
          Uri.parse('https://iskoala.com/yasal/kullanim-kosullari'),
        ]);
        expect(openedModes, [LaunchMode.externalApplication]);
        expect(changedValues, isEmpty);

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        expect(changedValues, [true]);
        expect(openedUrls, hasLength(1));
      },
    );
  }

  for (final contentUrl in [
    null,
    '',
    'http://iskoala.com/yasal/kullanim-kosullari',
    'file:///tmp/kullanim-kosullari.html',
    'koala://hesap-dogrula?token=gizli',
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('HTTPS olmayan adres düz metin kalır ve kutuyu işaretler: '
          '$contentUrl, $brightness', (tester) async {
        final openedUrls = <Uri>[];
        final changedValues = <bool>[];
        final browser = LegalDocumentBrowser(
          launch: (url, _) async {
            openedUrls.add(url);
            return true;
          },
        );
        const label = "Kullanım Koşulları'nı okudum, kabul ediyorum.";

        await pumpInApp(
          tester,
          ConsentCheckbox(
            label: label,
            linkText: 'Kullanım Koşulları',
            contentUrl: contentUrl,
            legalBrowser: browser,
            value: false,
            onChanged: changedValues.add,
          ),
          brightness: brightness,
        );

        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.decoration, isNot(TextDecoration.underline));

        await tester.tap(find.text(label));
        await tester.pump();

        expect(openedUrls, isEmpty);
        expect(changedValues, [true]);
      });
    }
  }

  testWidgets('etikette geçmeyen sözleşme adı bağlantı olarak eklenir', (
    tester,
  ) async {
    final openedUrls = <Uri>[];
    final browser = LegalDocumentBrowser(
      launch: (url, _) async {
        openedUrls.add(url);
        return true;
      },
    );

    await pumpInApp(
      tester,
      ConsentCheckbox(
        label: 'Kampanya ve duyurular için ticari ileti almak istiyorum.',
        linkText: 'Ticari İleti İzni',
        contentUrl: 'https://iskoala.com/yasal/ticari-ileti',
        legalBrowser: browser,
        value: false,
        onChanged: (_) => fail('Bağlantı onay değerini değiştirmemeli'),
      ),
    );

    await tester.tap(find.text('Ticari İleti İzni'));
    await tester.pump();

    expect(openedUrls, [Uri.parse('https://iskoala.com/yasal/ticari-ileti')]);
  });
}
