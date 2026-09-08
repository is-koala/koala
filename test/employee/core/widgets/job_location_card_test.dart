import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/core/widgets/job_location_card.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_icons.dart';

import '../../../support/finders.dart';
import '../../../support/pump.dart';

/// Sunucunun `EXACT` yanıtta gönderdiği açık adres.
const _exactLabel = 'Caferağa Mah. Moda Cad. No:12 D:4, Kadıköy';

/// `APPROXIMATE` yanıtta sunucu sokağı, binayı ve daireyi silip yalnız bunu
/// bırakıyor.
const _maskedLabel = 'Caferağa, Kadıköy, İstanbul';

/// İddiaların hepsi kartın **kendi** ağacında aranıyor. Komşu bir düğümün
/// olumlu iddiayı karşılaması bu yüzden mümkün değil: kart hiç çizilmezse
/// olumlu iddia da düşer.
Finder _inCard(Finder matching) =>
    find.descendant(of: find.byType(JobLocationCard), matching: matching);

Future<void> _pumpCard(
  WidgetTester tester, {
  required AddressPrecision precision,
  required String label,
  required Brightness brightness,
}) {
  return pumpInApp(
    tester,
    JobLocationCard(precision: precision, label: label),
    brightness: brightness,
  );
}

void main() {
  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    // İsimler iki durum sayıyor, dört aktör değil. Aktör → kesinlik eşlemesini
    // sunucu kuruyor (`JobAddressVisibility`) ve mobilde onu bağlayan hiçbir
    // şey yok; kartın gördüğü tek şey bayrak. "İşveren", "atanmış çalışan",
    // "diğer kullanıcı", "anonim ziyaretçi" diye dört test yazmak, ölçülmeyen
    // bir eşlemeyi ölçüyormuş gibi gösterirdi.
    group('Konum kartı ($themeName tema)', () {
      testWidgets('kesin konumda başlık "Konum" ve açık adres yazıyor', (
        tester,
      ) async {
        await _pumpCard(
          tester,
          precision: AddressPrecision.exact,
          label: _exactLabel,
          brightness: brightness,
        );

        expect(_inCard(find.text('Konum')), findsOneWidget);
        expect(_inCard(find.text('Yaklaşık konum')), findsNothing);
        expect(_inCard(find.text(_exactLabel)), findsOneWidget);
        expect(_inCard(find.textContaining('Tam adres')), findsNothing);
      });

      testWidgets('yaklaşık konumda başlık "Yaklaşık konum" oluyor', (
        tester,
      ) async {
        await _pumpCard(
          tester,
          precision: AddressPrecision.approximate,
          label: _maskedLabel,
          brightness: brightness,
        );

        expect(_inCard(find.text('Yaklaşık konum')), findsOneWidget);
        expect(_inCard(find.text('Konum')), findsNothing);
        expect(_inCard(find.text(_maskedLabel)), findsOneWidget);
      });

      testWidgets('ikonu katalogdan çiziyor', (tester) async {
        // Yeni dosya: `Icons.*` değil `AppIcon` — `find.byIcon` de bu yüzden
        // işe yaramaz, arama ikonun adı üzerinden yapılıyor.
        await _pumpCard(
          tester,
          precision: AddressPrecision.approximate,
          label: _maskedLabel,
          brightness: brightness,
        );

        expect(_inCard(findAppIcon(AppIcons.location)), findsOneWidget);
      });

      testWidgets('yaklaşık konumda tam adresin ne zaman açılacağı yazıyor', (
        tester,
      ) async {
        await _pumpCard(
          tester,
          precision: AddressPrecision.approximate,
          label: _maskedLabel,
          brightness: brightness,
        );

        expect(
          _inCard(find.textContaining('atama kurulduğunda')),
          findsOneWidget,
        );
      });
    });
  }
}
