import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/availability.dart';
import 'package:koala/product/models/availability_day.dart';
import 'package:koala/product/models/availability_exception.dart';
import 'package:koala/product/models/availability_slot.dart';
import 'package:koala/product/widgets/availability_view.dart';

import '../../support/pump.dart';

void main() {
  testWidgets('boş müsaitlik açıklayıcı durum gösterir', (tester) async {
    await pumpInApp(
      tester,
      AvailabilityView(
        availability: Availability(slots: const [], exceptions: const []),
      ),
    );

    expect(find.text('Müsaitlik bilgisi paylaşılmamış.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('haftalık aralık ve tarih istisnasını Türkçe gösterir', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      AvailabilityView(
        availability: Availability(
          slots: const [
            AvailabilitySlot(
              day: AvailabilityDay.monday,
              startTime: '09:00',
              endTime: '17:00',
            ),
          ],
          exceptions: [
            AvailabilityException(
              id: 'exception_1',
              date: DateTime(2026, 9, 12),
              available: false,
              note: 'Şehir dışında',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Pazartesi'), findsOneWidget);
    expect(find.text('09:00–17:00'), findsOneWidget);
    expect(find.text('12.09.2026'), findsOneWidget);
    expect(find.text('Çalışamam'), findsOneWidget);
    expect(find.text('Şehir dışında'), findsOneWidget);
  });

  testWidgets('yükleme hatası yeniden deneme eylemi gösterir', (tester) async {
    var retried = false;
    await pumpInApp(
      tester,
      AvailabilityView(
        availability: null,
        errorMessage: 'Müsaitlik alınamadı',
        onRetry: () => retried = true,
      ),
    );

    await tester.tap(find.text('Tekrar dene'));
    expect(retried, isTrue);
  });

  testWidgets('koyu temada da çizilir', (tester) async {
    await pumpInApp(
      tester,
      AvailabilityView(
        availability: Availability(slots: const [], exceptions: const []),
      ),
      brightness: Brightness.dark,
    );

    expect(tester.takeException(), isNull);
  });
}
