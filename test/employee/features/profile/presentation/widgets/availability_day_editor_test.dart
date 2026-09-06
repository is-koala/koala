import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/presentation/widgets/availability_day_editor.dart';
import 'package:koala/product/models/availability_day.dart';
import 'package:koala/product/models/availability_slot.dart';

import '../../../../../support/pump.dart';

void main() {
  testWidgets('günü ve bütün aralıklarını gösterip silme eylemini iletir', (
    tester,
  ) async {
    int? removedIndex;
    await pumpInApp(
      tester,
      AvailabilityDayEditor(
        day: AvailabilityDay.monday,
        slots: const [
          AvailabilitySlot(
            day: AvailabilityDay.monday,
            startTime: '09:00',
            endTime: '12:00',
          ),
          AvailabilitySlot(
            day: AvailabilityDay.monday,
            startTime: '13:00',
            endTime: '17:00',
          ),
        ],
        onAdd: () {},
        onRemove: (index) => removedIndex = index,
      ),
    );

    expect(find.text('Pazartesi'), findsOneWidget);
    expect(find.text('09:00–12:00'), findsOneWidget);
    expect(find.text('13:00–17:00'), findsOneWidget);

    await tester.tap(find.byTooltip('13:00–17:00 aralığını kaldır'));
    expect(removedIndex, 1);
  });
}
