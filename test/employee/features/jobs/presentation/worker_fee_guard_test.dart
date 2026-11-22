import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Çalışan kabuğu komisyon çizmez (#189). Eski sunucu gönderse de: bu test
/// kaynak ağacını okuyup çalışan tarafındaki **hiçbir** sunum dosyasının o
/// alanlara dokunmadığını sabitliyor.
void main() {
  test('çalışan sunum katmanı komisyon alanlarını okumaz', () {
    final offenders = <String>[];
    final roots = [
      Directory('lib/employee/core'),
      ...Directory('lib/employee/features')
          .listSync()
          .whereType<Directory>()
          .map((feature) => Directory('${feature.path}/presentation')),
    ];
    // Alan adları ve satır başlıkları, büyük/küçük harf duyarsız; yorumlar
    // ayıklanıyor.
    final forbidden = RegExp(
      r'\b(serviceFeeAmount|serviceFeeRate|serviceFeePercentLabel|'
      r'employerTotal|totalCharged)\b|\?\.pricing\b|\.pricing\b|'
      r'hizmet bedeli|işverenin ödediği',
      caseSensitive: false,
    );

    var scanned = 0;
    for (final root in roots) {
      if (!root.existsSync()) continue;
      final files = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      for (final file in files) {
        scanned++;
        final code = file
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n');
        if (forbidden.hasMatch(code)) offenders.add(file.path);
      }
    }

    // Boş tarama boş bir geçiş olurdu: klasör taşınırsa test bunu söylesin.
    expect(
      scanned,
      greaterThan(0),
      reason:
          'Çalışan sunum klasörleri bulunamadı; tarama kökleri güncellenmeli.',
    );
    // Kuralın asıl adresi olan klasör de taramada olmalı.
    expect(
      Directory('lib/employee/features/jobs/presentation').existsSync(),
      isTrue,
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar çalışan kabuğunda komisyon alanı okuyor ya da satırı '
          'yazıyor; çalışan yalnız kendi kazancını (workerPayout) görür.',
    );
  });
}
