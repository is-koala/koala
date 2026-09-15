import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
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

  testWidgets('kesin konumlu ilanda uzaklık ondalıklı yazılıyor', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      JobCard(
        job: buildJob(
          addressPrecision: AddressPrecision.exact,
          distanceKm: 2.34,
        ),
      ),
    );

    expect(find.text('2.3 km'), findsOneWidget);
  });

  testWidgets('yaklaşık konumlu ilanda uzaklık yuvarlanıp işaretleniyor', (
    tester,
  ) async {
    // Harita aynı ilanı belirsizlik dairesiyle çizerken listenin "2.3 km"
    // demesi, veride olmayan 100 m'lik bir çözünürlük iddia ederdi.
    await pumpInApp(
      tester,
      JobCard(
        job: buildJob(
          addressPrecision: AddressPrecision.approximate,
          distanceKm: 2.34,
        ),
      ),
    );

    expect(find.text('~2 km'), findsOneWidget);
    expect(find.text('2.3 km'), findsNothing);
  });

  testWidgets('distanceKm yokken mesafe satırı gizleniyor', (tester) async {
    await pumpInApp(tester, JobCard(job: buildJob()));

    expect(find.textContaining('km'), findsNothing);
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
