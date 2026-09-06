import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/presentation/widgets/availability_exception_sheet.dart';

import '../../../../../support/pump.dart';

Future<void> openSheet(WidgetTester tester) async {
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => AvailabilityExceptionSheet.show(context),
        child: const Text('aç'),
      ),
    ),
  );

  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tarih seçici geçmiş günü seçtirmez', (tester) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const ValueKey('availability-exception-date')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(DateUtils.isSameDay(dialog.firstDate, DateTime.now()), isTrue);
  });

  testWidgets('not alanını 255 karakterde sınırlar', (tester) async {
    await openSheet(tester);

    final noteField = find.byKey(const ValueKey('availability-exception-note'));
    await tester.enterText(noteField, 'a' * 300);

    final field = tester.widget<TextField>(noteField);
    expect(field.controller?.text, hasLength(255));
  });

  testWidgets('sheet içinde ListTile kurmaz', (tester) async {
    await openSheet(tester);

    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
