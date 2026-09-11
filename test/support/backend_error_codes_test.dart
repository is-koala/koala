import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_error_codes.dart';

void main() {
  group('deriveErrorCode', () {
    test('süslü parantezli mesaj anahtarını Java ile aynı koda çevirir', () {
      expect(
        BackendErrorCodes.deriveErrorCode('{job.alert.too.many}'),
        'JOB_ALERT_TOO_MANY',
      );
    });

    test('properties satırındaki ham anahtarı da çevirir', () {
      expect(
        BackendErrorCodes.deriveErrorCode('identity.sod.unreadable'),
        'IDENTITY_SOD_UNREADABLE',
      );
    });
  });

  group('parseProperties', () {
    test('anahtarlardan kod üretir, yorumları atlar', () {
      const source = '''
# yorum
job.alert.too.many=Daha fazla iş alarmı oluşturamazsınız.
identity.evidence.required=Kanıt gerekli.
''';

      expect(BackendErrorCodes.parseProperties(source), {
        'JOB_ALERT_TOO_MANY',
        'IDENTITY_EVIDENCE_REQUIRED',
      });
    });
  });

  group('routedCodesIn', () {
    test('Dart kaynağındaki yönlendirme kodlarını okur', () {
      const source = '''
static const String _quotaExceededCode = 'JOB_ALERT_TOO_MANY';
case 'JOB_TEMPLATE_NOT_FOUND':
''';

      expect(BackendErrorCodes.routedCodesIn(source), {
        'JOB_ALERT_TOO_MANY',
        'JOB_TEMPLATE_NOT_FOUND',
      });
    });
  });

  group('sözleşme', () {
    test('yönlendirilen her kod messages_tr anahtarından türüyor', () {
      final catalog = BackendErrorCodes.load();
      final routed = BackendErrorCodes.routedCodesFromLib();

      expect(routed, isNotEmpty);
      expect(
        catalog,
        containsAll(routed),
        reason:
            'Mobilin baktığı errorCode backend mesaj anahtarında yok; '
            'yazım hatası ham metne düşer:\n'
            '${routed.difference(catalog).join('\n')}',
      );
    });
  });

  group('kaynak çözümü', () {
    late Directory scratch;

    setUp(
      () => scratch = Directory.systemTemp.createTempSync('koala-errcode-'),
    );
    tearDown(() {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    test('KOALA_BACKEND_ROOT properties dosyasını okur', () {
      final backend = Directory('${scratch.path}/koala-backend')..createSync();
      File('${backend.path}/${BackendErrorCodes.propertiesRelativePath}')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('job.alert.too.many=quota\n');

      expect(
        BackendErrorCodes.load(
          from: Directory('${scratch.path}/koala-mobile')..createSync(),
          environment: {'KOALA_BACKEND_ROOT': backend.path},
        ),
        {'JOB_ALERT_TOO_MANY'},
      );
    });
  });
}
