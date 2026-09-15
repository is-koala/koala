import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job_search_query.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_sort_sheet.dart';
import 'package:koala/product/widgets/filter_pill.dart';

import '../../../../../support/pump.dart';

void main() {
  testWidgets('konum yokken En yakın kapalı ve sebebi yazılıyor', (
    tester,
  ) async {
    await pumpInApp(tester, const JobSortSheet(selected: JobSortOption.newest));

    expect(find.text('En yakın'), findsOneWidget);
    expect(
      find.text('Yakınlık sıralaması için konum izni gerekiyor.'),
      findsOneWidget,
    );

    final nearest = tester.widget<FilterPill>(
      find.ancestor(
        of: find.text('En yakın'),
        matching: find.byType(FilterPill),
      ),
    );
    expect(nearest.enabled, isFalse);
  });

  testWidgets('konum varken En yakın seçilebiliyor', (tester) async {
    JobSortOption? picked;

    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            picked = await JobSortSheet.show(
              context,
              selected: JobSortOption.newest,
              hasLocation: true,
            );
          },
          child: const Text('aç'),
        ),
      ),
    );

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(
      find.text('Yakınlık sıralaması için konum izni gerekiyor.'),
      findsNothing,
    );

    await tester.tap(find.text('En yakın'));
    await tester.pumpAndSettle();

    expect(picked, JobSortOption.nearest);
  });
}
