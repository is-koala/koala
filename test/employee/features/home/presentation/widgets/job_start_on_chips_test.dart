import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_start_on.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_start_on_chips.dart';

import '../../../../../support/pump.dart';

void main() {
  testWidgets('hazır çipler ve Tarih seç görünüyor', (tester) async {
    await pumpInApp(tester, JobStartOnChips(selected: null, onChanged: (_) {}));

    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Yarın'), findsOneWidget);
    expect(find.text('Hafta sonu'), findsOneWidget);
    expect(find.text('Bu hafta'), findsOneWidget);
    expect(find.text('Tarih seç'), findsOneWidget);
  });

  testWidgets(
    'Bugün çipine basınca seçim değişiyor, tekrar basınca temizleniyor',
    (tester) async {
      JobStartOn? selected;

      await pumpInApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            return JobStartOnChips(
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            );
          },
        ),
      );

      await tester.tap(find.text('Bugün'));
      await tester.pump();
      expect(selected, JobStartOn.today);

      await tester.tap(find.text('Bugün'));
      await tester.pump();
      expect(selected, isNull);
    },
  );

  testWidgets('seçili takvim günü Tarih seç yerine tarihi yazar', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      JobStartOnChips(
        selected: JobStartOn.calendarDay(DateTime(2026, 9, 20)),
        onChanged: (_) {},
      ),
    );

    expect(find.text('20.09.2026'), findsOneWidget);
    expect(find.text('Tarih seç'), findsNothing);
  });
}
