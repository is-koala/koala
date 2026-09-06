import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/services/gallery_upload_validator.dart';

void main() {
  test('desteklenmeyen görsel türünü yüklemeden reddediyor', () async {
    expect(
      await GalleryUploadValidator.errorFor('/tmp/image.gif'),
      'Yalnızca PNG, JPG veya WEBP yükleyebilirsiniz',
    );
  });

  test('10 MB üstündeki görseli yüklemeden reddediyor', () async {
    final file = File('${Directory.systemTemp.path}/koala_large_gallery.png');
    await file.writeAsBytes(const [1]);
    await file.open(mode: FileMode.append).then((handle) async {
      await handle.setPosition(10 * 1024 * 1024);
      await handle.writeByte(1);
      await handle.close();
    });
    addTearDown(() => file.deleteSync());

    expect(
      await GalleryUploadValidator.errorFor(file.path),
      'Görsel en fazla 10 MB olabilir',
    );
  });

  test('desteklenen ve küçük görseli kabul ediyor', () async {
    final file = File('${Directory.systemTemp.path}/koala_small_gallery.webp')
      ..writeAsBytesSync(const [1, 2, 3]);
    addTearDown(() => file.deleteSync());

    expect(await GalleryUploadValidator.errorFor(file.path), isNull);
  });
}
