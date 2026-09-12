import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'kamera eklentisinin gereksiz Android izinleri birleşimde kaldırılır',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('xmlns:tools="http://schemas.android.com/tools"'),
      );
      expect(
        manifest,
        contains(
          'android:name="android.permission.RECORD_AUDIO" tools:node="remove"',
        ),
      );
      expect(
        manifest,
        contains(
          'android:name="android.permission.WRITE_EXTERNAL_STORAGE" '
          'tools:node="remove"',
        ),
      );
    expect(
      manifest,
      contains(
        'android:name="android.hardware.camera.any" '
        'android:required="false" tools:replace="android:required"',
      ),
    );
    },
  );
}
