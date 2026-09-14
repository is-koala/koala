import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/chat/models/messaging_availability.dart';
import 'package:koala/employee/features/chat/models/messaging_gate_error_codes.dart';

void main() {
  group('MessagingAvailability.fromJson', () {
    test('messagingAvailable true ise kapı açık', () {
      final availability = MessagingAvailability.fromJson({
        'messagingAvailable': true,
        'messagingAvailableReason': 'AVAILABLE',
      });

      expect(availability.isAvailable, isTrue);
      expect(availability.reason, MessagingAvailabilityReason.available);
      expect(availability.noteFor(asEmployer: false), isNull);
      expect(availability.noteFor(asEmployer: true), isNull);
    });

    test('ödeme bekleniyor sebebi okunur', () {
      final availability = MessagingAvailability.fromJson({
        'messagingAvailable': false,
        'messagingAvailableReason': 'PAYMENT_REQUIRED',
      });

      expect(availability.isAvailable, isFalse);
      expect(availability.needsPayment, isTrue);
      expect(availability.isClosed, isFalse);
    });

    test('kapalı pencere sebebi okunur', () {
      final availability = MessagingAvailability.fromJson({
        'messagingAvailable': false,
        'messagingAvailableReason': 'CLOSED',
      });

      expect(availability.isAvailable, isFalse);
      expect(availability.isClosed, isTrue);
      expect(availability.needsPayment, isFalse);
    });

    // Backend sözleşmesi bu alanları PR 261 ile ekliyor; eski sunucuya karşı
    // düğme gizli kalmalı, çünkü o sunucu da ödeme öncesi sohbeti reddediyor.
    test('alanlar hiç yoksa (eski sunucu) ödeme bekleniyor sayılır', () {
      final availability = MessagingAvailability.fromJson({
        'id': 'asg_1',
        'status': 'CONFIRMED',
      });

      expect(availability.isAvailable, isFalse);
      expect(availability.needsPayment, isTrue);
      expect(availability.reason, MessagingAvailabilityReason.paymentRequired);
    });

    test('tanınmayan sebep açık kapı sayılmaz', () {
      final availability = MessagingAvailability.fromJson({
        'messagingAvailable': false,
        'messagingAvailableReason': 'UZAYLI',
      });

      expect(availability.isAvailable, isFalse);
      expect(availability.needsPayment, isTrue);
    });

    test('kapı kapalıyken AVAILABLE sebebi bayrağı geçersiz kılmaz', () {
      final availability = MessagingAvailability.fromJson({
        'messagingAvailable': false,
        'messagingAvailableReason': 'AVAILABLE',
      });

      expect(availability.isAvailable, isFalse);
      expect(availability.needsPayment, isTrue);
    });

    test('sebep gelmeden bayrak true ise yine açık', () {
      final availability = MessagingAvailability.fromJson({
        'messagingAvailable': true,
      });

      expect(availability.isAvailable, isTrue);
    });
  });

  group('MessagingAvailability.noteFor', () {
    test('ödeme bekleniyor metni tarafa göre değişir', () {
      const availability = MessagingAvailability.paymentRequired;

      expect(
        availability.noteFor(asEmployer: false),
        'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
      );
      expect(
        availability.noteFor(asEmployer: true),
        'Ödemeyi tamamlayınca ekip sohbeti açılır.',
      );
    });

    test('kapalı sohbet metni iki tarafta aynı', () {
      const availability = MessagingAvailability.closed;

      expect(availability.noteFor(asEmployer: false), 'Bu sohbet kapandı');
      expect(availability.noteFor(asEmployer: true), 'Bu sohbet kapandı');
    });
  });

  group('MessagingAvailability.fromErrorCode', () {
    test('403 MESSAGING_PAYMENT_REQUIRED ödeme metnine gider', () {
      final gate = MessagingAvailability.fromErrorCode(
        MessagingGateErrorCodes.paymentRequired,
      );

      expect(gate, isNotNull);
      expect(gate!.needsPayment, isTrue);
      expect(
        gate.noteFor(asEmployer: false),
        'Mesajlaşma, işveren ödemeyi tamamladığında açılır.',
      );
      expect(
        gate.noteFor(asEmployer: true),
        'Ödemeyi tamamlayınca ekip sohbeti açılır.',
      );
    });

    test('409 MESSAGING_WINDOW_CLOSED kapalı sohbet metnine gider', () {
      final gate = MessagingAvailability.fromErrorCode(
        MessagingGateErrorCodes.windowClosed,
      );

      expect(gate, isNotNull);
      expect(gate!.isClosed, isTrue);
      expect(gate.noteFor(asEmployer: false), 'Bu sohbet kapandı');
    });

    // Engel (`messaging.blocked`) de 403 ile geliyor; onun ekranı ayrı, kapı
    // sayılmamalı.
    test('kapıyla ilgisi olmayan kodda null', () {
      expect(MessagingAvailability.fromErrorCode('MESSAGING_BLOCKED'), isNull);
      expect(MessagingAvailability.fromErrorCode('ACCESS_DENIED'), isNull);
      expect(MessagingAvailability.fromErrorCode(null), isNull);
    });

    // Hata kodundan gelen kapı ile DTO'dan gelen kapı aynı nesne: ekran
    // hangisinden geldiğine bakmadan aynı cümleyi yazmalı.
    test('hata kodundan gelen kapı DTO kapısıyla aynı metni verir', () {
      for (final asEmployer in [false, true]) {
        expect(
          MessagingAvailability.fromErrorCode(
            MessagingGateErrorCodes.paymentRequired,
          )!.noteFor(asEmployer: asEmployer),
          MessagingAvailability.fromJson({
            'messagingAvailable': false,
            'messagingAvailableReason': 'PAYMENT_REQUIRED',
          }).noteFor(asEmployer: asEmployer),
        );
        expect(
          MessagingAvailability.fromErrorCode(
            MessagingGateErrorCodes.windowClosed,
          )!.noteFor(asEmployer: asEmployer),
          MessagingAvailability.fromJson({
            'messagingAvailable': false,
            'messagingAvailableReason': 'CLOSED',
          }).noteFor(asEmployer: asEmployer),
        );
      }
    });
  });

  group('MessagingAvailabilityReason.fromCode', () {
    test('üç sebep sunucu koduyla eşleşir', () {
      expect(
        MessagingAvailabilityReason.fromCode('PAYMENT_REQUIRED'),
        MessagingAvailabilityReason.paymentRequired,
      );
      expect(
        MessagingAvailabilityReason.fromCode('CLOSED'),
        MessagingAvailabilityReason.closed,
      );
      expect(
        MessagingAvailabilityReason.fromCode('AVAILABLE'),
        MessagingAvailabilityReason.available,
      );
    });

    test('tanınmayan ve eksik değer null', () {
      expect(MessagingAvailabilityReason.fromCode('UZAYLI'), isNull);
      expect(MessagingAvailabilityReason.fromCode(null), isNull);
    });
  });
}
