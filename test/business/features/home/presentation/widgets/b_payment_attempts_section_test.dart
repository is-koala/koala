import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/models/b_payment_attempt.dart';
import 'package:koala/business/features/home/presentation/widgets/b_payment_attempts_section.dart';

import '../../../../../support/pump.dart';

void main() {
  final succeeded = BPaymentAttempt.fromJson(const {
    'id': 'attempt-1',
    'status': 'SUCCEEDED',
    'currency': 'TRY',
    'workerPayout': '1000.10',
    'commissionAmount': '50.01',
    'commissionRate': '0.050',
    'totalCharged': '1050.11',
    'createdAt': '2026-09-06T12:00:00Z',
    'completedAt': '2026-09-06T12:03:30Z',
  });
  final pending = BPaymentAttempt.fromJson(const {
    'id': 'attempt-2',
    'status': 'INITIATED',
    'currency': 'TRY',
    'workerPayout': '1000.10',
    'commissionAmount': '50.01',
    'commissionRate': '0.050',
    'totalCharged': '1050.11',
    'createdAt': '2026-09-06T12:00:00Z',
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'tamamlanma anını ve dökümü satırda gösterir (${brightness.name})',
      (tester) async {
        await pumpInApp(
          tester,
          BPaymentAttemptsSection(
            attempts: [succeeded, pending],
            isLoading: false,
            onRetry: () {},
          ),
          brightness: brightness,
        );

        final completedLabel = succeeded.completedAt!.toLocal();
        expect(
          find.textContaining(
            'Tamamlandı: ${completedLabel.day.toString().padLeft(2, '0')}.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Çalışan ücreti: 1.000,10 ₺ · Komisyon: 50,01 ₺ (%5)'),
          findsNWidgets(2),
        );
        expect(
          find.byKey(const ValueKey('payment-attempt-breakdown-attempt-1')),
          findsOneWidget,
        );
      },
    );
  }

  // Süren denemede tamamlanma anı yok; satır yalnızca başlangıcı yazmalı.
  testWidgets('tamamlanmamış denemede yalnızca başlangıç anı yazar', (
    tester,
  ) async {
    await pumpInApp(
      tester,
      BPaymentAttemptsSection(
        attempts: [pending],
        isLoading: false,
        onRetry: () {},
      ),
    );

    expect(find.textContaining('Tamamlandı:'), findsNothing);
    expect(find.text('Başlatıldı'), findsOneWidget);
  });
}
