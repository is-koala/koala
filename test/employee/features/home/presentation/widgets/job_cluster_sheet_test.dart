import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_cluster_sheet.dart';

import '../../../../../support/fixtures.dart';
import '../../../../../support/pump.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} temada noktadaki ilanları listeler', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        JobClusterSheet(
          jobs: [
            buildJob(id: 'a', title: 'Garson'),
            buildJob(id: 'b', title: 'Barista'),
          ],
        ),
        brightness: brightness,
      );

      expect(find.text('Bu noktada 2 ilan'), findsOneWidget);
      expect(find.byType(JobCard), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }
}
