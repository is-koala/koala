import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/presentation/widgets/job_card.dart';

import '../../../../../support/fixtures.dart';
import '../../../../../support/pump.dart';

void main() {
  testWidgets('sunucunun kapak görselini ilan kartında gösteriyor', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      JobCard(job: buildJob(coverImageUrl: 'https://cdn.local/job-cover.webp')),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://cdn.local/job-cover.webp',
    );
  });

  testWidgets('kapak yoksa kategori avatarına dönüyor', (tester) async {
    await pumpInApp(tester, JobCard(job: buildJob()));

    expect(find.byType(Image), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('bozuk kapakta kategori avatarına dönüyor', (tester) async {
    await pumpInApp(tester, JobCard(job: buildJob(coverImageUrl: 'not-a-url')));
    await tester.pumpAndSettle();

    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('390 piksel genişlikte kapaklı kart taşmıyor', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpInApp(
      tester,
      JobCard(job: buildJob(coverImageUrl: 'https://cdn.local/job-cover.webp')),
    );

    expect(tester.takeException(), isNull);
  });
}
