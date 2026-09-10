import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_error_categories.dart';

void main() {
  group('ErrorCategory.java', () {
    test('enum sabitlerini gövdeden okur', () {
      const source = '''
package com.exskylab.koala.core.utilities.results;

public enum ErrorCategory {
    RESOURCE_NOT_FOUND,
    VALIDATION_FAILED,
    UNEXPECTED
}
''';

      expect(BackendErrorCategories.parseJava(source), {
        'RESOURCE_NOT_FOUND',
        'VALIDATION_FAILED',
        'UNEXPECTED',
      });
    });

    test('yorum satırındaki sahte sabiti saymaz', () {
      const source = '''
public enum ErrorCategory {
    RESOURCE_NOT_FOUND,
    // DROPPED_CATEGORY,
    /* ALSO_DROPPED */
    UNEXPECTED
}
''';

      expect(BackendErrorCategories.parseJava(source), {
        'RESOURCE_NOT_FOUND',
        'UNEXPECTED',
      });
    });
  });

  group('OpenAPI', () {
    test('ErrorCategory şemasındaki enum listesini okur', () {
      const document = '''
{
  "components": {
    "schemas": {
      "ErrorCategory": {
        "type": "string",
        "enum": ["RESOURCE_NOT_FOUND", "UNEXPECTED"]
      },
      "ErrorResult": {
        "properties": {
          "errorCategory": {
            "\$ref": "#/components/schemas/ErrorCategory"
          }
        }
      }
    }
  }
}
''';

      expect(BackendErrorCategories.parseOpenApi(document), {
        'RESOURCE_NOT_FOUND',
        'UNEXPECTED',
      });
    });

    test('ErrorResult özelliğine gömülü enum listesini okur', () {
      const document = '''
{
  "components": {
    "schemas": {
      "ErrorResult": {
        "properties": {
          "errorCategory": {
            "type": "string",
            "enum": ["ACCESS_DENIED", "TOKEN_EXPIRED"]
          }
        }
      }
    }
  }
}
''';

      expect(BackendErrorCategories.parseOpenApi(document), {
        'ACCESS_DENIED',
        'TOKEN_EXPIRED',
      });
    });
  });

  group('kaynak çözümü', () {
    late Directory scratch;

    setUp(() => scratch = Directory.systemTemp.createTempSync('koala-errcat-'));
    tearDown(() {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    test('kardeş koala-backend checkout\'undaki Java enum\'unu okur', () {
      final backend = Directory('${scratch.path}/koala-backend')..createSync();
      _writeJava(backend, const ['RESOURCE_NOT_FOUND', 'UNEXPECTED']);
      final mobile = Directory('${scratch.path}/koala-mobile')..createSync();

      expect(BackendErrorCategories.load(from: mobile), {
        'RESOURCE_NOT_FOUND',
        'UNEXPECTED',
      });
    });

    test('KOALA_OPENAPI_PATH Java dosyasından önce gelir', () {
      final backend = Directory('${scratch.path}/koala-backend')..createSync();
      _writeJava(backend, const ['RESOURCE_NOT_FOUND']);
      final openApi = File('${scratch.path}/openapi.json')
        ..writeAsStringSync('''
{
  "components": {
    "schemas": {
      "ErrorCategory": {
        "type": "string",
        "enum": ["TOKEN_EXPIRED", "ACCESS_DENIED"]
      }
    }
  }
}
''');

      expect(
        BackendErrorCategories.load(
          from: Directory('${scratch.path}/koala-mobile')..createSync(),
          environment: {
            'KOALA_BACKEND_ROOT': backend.path,
            'KOALA_OPENAPI_PATH': openApi.path,
          },
        ),
        {'TOKEN_EXPIRED', 'ACCESS_DENIED'},
      );
    });

    test('kaynak yoksa net bir hata verir', () {
      expect(
        () => BackendErrorCategories.load(
          from: Directory('${scratch.path}/lonely')..createSync(),
          environment: const {},
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('KOALA_BACKEND_ROOT'),
          ),
        ),
      );
    });
  });
}

void _writeJava(Directory backend, List<String> constants) {
  final file = File(
    '${backend.path}/src/main/java/com/exskylab/koala/core/utilities/results/ErrorCategory.java',
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('''
public enum ErrorCategory {
    ${constants.join(',\n    ')}
}
''');
}
