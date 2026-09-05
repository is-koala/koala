import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/widgets/auth_legal_footer.dart';
import 'package:koala/employee/features/auth/services/legal_document_browser.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'servisten gelen yasal metinler doğru HTTPS adreslerinde açılır: '
      '$brightness',
      (tester) async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'terms-1',
                  'type': 'TERMS_OF_SERVICE',
                  'version': '1.0',
                  'locale': 'tr',
                  'mandatory': true,
                  'contentUrl': 'https://iskoala.com/yasal/kullanim-kosullari',
                },
                {
                  'id': 'privacy-1',
                  'type': 'PRIVACY_POLICY',
                  'version': '1.0',
                  'locale': 'tr',
                  'mandatory': true,
                  'contentUrl': 'https://iskoala.com/yasal/gizlilik',
                },
              ],
            },
          ),
        );
        final openedUrls = <Uri>[];
        final openedModes = <LaunchMode>[];
        final browser = LegalDocumentBrowser(
          launch: (url, mode) async {
            openedUrls.add(url);
            openedModes.add(mode);
            return true;
          },
        );

        await pumpInApp(
          tester,
          AuthLegalFooter(
            legalService: LegalService.withClient(api.client),
            legalBrowser: browser,
          ),
          brightness: brightness,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kullanım Şartları'));
        await tester.tap(find.text('Gizlilik Politikası'));
        await tester.pump();

        expect(api.requests, hasLength(1));
        expect(openedUrls, [
          Uri.parse('https://iskoala.com/yasal/kullanim-kosullari'),
          Uri.parse('https://iskoala.com/yasal/gizlilik'),
        ]);
        expect(openedModes, [
          LaunchMode.externalApplication,
          LaunchMode.externalApplication,
        ]);
      },
    );

    testWidgets(
      'eksik veya HTTP içerik adresi ölü bağlantı gibi çizilmez: $brightness',
      (tester) async {
        final api = FakeApi(
          handler: (_) => const FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': [
                {
                  'id': 'terms-1',
                  'type': 'TERMS_OF_SERVICE',
                  'version': '1.0',
                  'locale': 'tr',
                  'mandatory': true,
                },
                {
                  'id': 'privacy-1',
                  'type': 'PRIVACY_POLICY',
                  'version': '1.0',
                  'locale': 'tr',
                  'mandatory': true,
                  'contentUrl': 'http://iskoala.com/yasal/gizlilik',
                },
              ],
            },
          ),
        );
        final openedUrls = <Uri>[];
        final browser = LegalDocumentBrowser(
          launch: (url, _) async {
            openedUrls.add(url);
            return true;
          },
        );

        await pumpInApp(
          tester,
          AuthLegalFooter(
            legalService: LegalService.withClient(api.client),
            legalBrowser: browser,
          ),
          brightness: brightness,
        );
        await tester.pumpAndSettle();

        final terms = tester.widget<Text>(find.text('Kullanım Şartları'));
        final privacy = tester.widget<Text>(find.text('Gizlilik Politikası'));
        expect(terms.style?.decoration, isNot(TextDecoration.underline));
        expect(privacy.style?.decoration, isNot(TextDecoration.underline));

        await tester.tap(find.text('Kullanım Şartları'));
        await tester.tap(find.text('Gizlilik Politikası'));
        await tester.pump();

        expect(openedUrls, isEmpty);
      },
    );
  }
}
