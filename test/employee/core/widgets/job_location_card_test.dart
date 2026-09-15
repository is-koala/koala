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
  VoidCallback? onDirections,
  DateTime? arrival,
}) {
  return pumpInApp(
    tester,
    JobLocationCard(
      precision: precision,
      label: label,
      onDirections: onDirections,
      arrival: arrival,
    ),
    brightness: brightness,
  );
}

/// "Yol tarifi al" düğmesi.
final _directionsButton = find.byKey(const ValueKey('job-location-directions'));

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

      // is-koala/koala#188: düğme yalnız kesin konumda ve sayfa bir hedef
      // verdiyse. Kart varış saatini bağlantıya değil metne yazıyor.
      group('yol tarifi', () {
        testWidgets('kesin konum + hedef: düğme, ikon ve başlangıç notu', (
          tester,
        ) async {
          var taps = 0;
          await _pumpCard(
            tester,
            precision: AddressPrecision.exact,
            label: _exactLabel,
            brightness: brightness,
            onDirections: () => taps++,
            arrival: DateTime(2026, 9, 10, 9),
          );

          expect(_inCard(_directionsButton), findsOneWidget);
          expect(_inCard(find.text('Yol tarifi al')), findsOneWidget);
          expect(_inCard(findAppIcon(AppIcons.route)), findsOneWidget);
          expect(
            _inCard(
              find.text(
                'Toplu taşıma rotası harita uygulamasında açılır. İş '
                'başlangıcı 10.09.2026 09:00; varış saatini orada '
                'seçebilirsiniz.',
              ),
            ),
            findsOneWidget,
          );

          await tester.tap(_directionsButton);
          await tester.pump();

          expect(taps, 1);
        });

        testWidgets('başlangıç bilinmiyorsa not saatsiz, "siz" hitabı', (
          tester,
        ) async {
          await _pumpCard(
            tester,
            precision: AddressPrecision.exact,
            label: _exactLabel,
            brightness: brightness,
            onDirections: () {},
          );

          expect(
            _inCard(
              find.text(
                'Toplu taşıma rotası harita uygulamasında açılır; varış '
                'saatini orada seçebilirsiniz.',
              ),
            ),
            findsOneWidget,
          );
          expect(_inCard(find.textContaining('seçebilirsin.')), findsNothing);
        });

        testWidgets('hedef verilmediyse düğme yok', (tester) async {
          await _pumpCard(
            tester,
            precision: AddressPrecision.exact,
            label: _exactLabel,
            brightness: brightness,
          );

          expect(_inCard(_directionsButton), findsNothing);
          expect(_inCard(find.textContaining('Toplu taşıma')), findsNothing);
        });

        // Sunucu yaklaşık derken hedef verilmiş olsa bile düğme çizilmez:
        // yuvarlanmış koordinata rota, olmayan bir kapıya götürür.
        testWidgets('yaklaşık konumda hedef verilse de düğme yok', (
          tester,
        ) async {
          await _pumpCard(
            tester,
            precision: AddressPrecision.approximate,
            label: _maskedLabel,
            brightness: brightness,
            onDirections: () {},
            arrival: DateTime(2026, 9, 10, 9),
          );

          expect(_inCard(_directionsButton), findsNothing);
          expect(_inCard(find.text('Yol tarifi al')), findsNothing);
          expect(_inCard(find.textContaining('Toplu taşıma')), findsNothing);
        });
      });
    });
  }
}
