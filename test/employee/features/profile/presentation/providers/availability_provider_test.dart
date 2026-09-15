import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/models/availability_day.dart';
import 'package:koala/product/models/availability_slot.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/product/services/availability_service.dart';

import '../../../../../support/fake_api.dart';

const Map<String, dynamic> _loadedAvailability = {
  'slots': [
    {
      'id': 'monday_1',
      'dayOfWeek': 'MONDAY',
      'startTime': '09:00:00',
      'endTime': '17:00:00',
    },
    {
      'id': 'tuesday_1',
      'dayOfWeek': 'TUESDAY',
      'startTime': '10:00:00',
      'endTime': '18:00:00',
    },
  ],
  'exceptions': [
    {
      'id': 'exception_1',
      'date': '2026-09-12',
      'available': false,
      'note': 'Şehir dışında',
    },
  ],
};

const Map<String, dynamic> _savedAvailability = {
  'slots': [
    {
      'id': 'monday_2',
      'dayOfWeek': 'MONDAY',
      'startTime': '08:00:00',
      'endTime': '12:00:00',
    },
    {
      'id': 'tuesday_2',
      'dayOfWeek': 'TUESDAY',
      'startTime': '10:00:00',
      'endTime': '18:00:00',
    },
  ],
  'exceptions': <Map<String, dynamic>>[],
};

AvailabilityProvider providerFor(FakeApi api) =>
    AvailabilityProvider(service: AvailabilityService.withClient(api.client));

/// Sağlayıcı bugünden önceki tarihi reddettiği için istisna tarihi sabit
/// değil, çalıştırma gününden 30 gün sonrası (takvim gerçek saate bağlı).
final DateTime _futureDate = DateUtils.dateOnly(
  DateTime.now().add(const Duration(days: 30)),
);
final String _futureIsoDate =
    '${_futureDate.year.toString().padLeft(4, '0')}-'
    '${_futureDate.month.toString().padLeft(2, '0')}-'
    '${_futureDate.day.toString().padLeft(2, '0')}';

void main() {
  test('tek bir günü düzenleyip kaydetmek bütün haftayı PUT eder', () async {
    final api = FakeApi(
      handler: (request) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': request.method == 'GET'
              ? _loadedAvailability
              : _savedAvailability,
        },
      ),
    );
    final provider = providerFor(api);
    await provider.load('user_1');

    provider.replaceDaySlots('user_1', AvailabilityDay.monday, const [
      AvailabilitySlot(
        day: AvailabilityDay.monday,
        startTime: '08:00',
        endTime: '12:00',
      ),
    ]);
    final saved = await provider.saveWeekly('user_1');

    final body = api.requests.last.data as Map<String, dynamic>;
    final slots = body['slots'] as List<dynamic>;
    expect(saved, isTrue);
    expect(api.requests, hasLength(2));
    final tuesday = slots.cast<Map<String, dynamic>>().singleWhere(
      (slot) => slot['dayOfWeek'] == 'TUESDAY',
    );
    expect(tuesday, const {
      'dayOfWeek': 'TUESDAY',
      'startTime': '10:00',
      'endTime': '18:00',
    }, reason: 'Salı değiştirilmediği için PUT gövdesinde korunmalı');
    expect(provider.availability?.exceptions, hasLength(1));
  });

  test(
    'aynı gün çakışan aralık Türkçe mesajla reddedilir ve PUT atılmaz',
    () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 200,
          body: {'success': true, 'data': _loadedAvailability},
        ),
      );
      final provider = providerFor(api);
      await provider.load('user_1');

      provider.replaceDaySlots('user_1', AvailabilityDay.monday, const [
        AvailabilitySlot(
          day: AvailabilityDay.monday,
          startTime: '09:00',
          endTime: '12:00',
        ),
        AvailabilitySlot(
          day: AvailabilityDay.monday,
          startTime: '11:00',
          endTime: '13:00',
        ),
      ]);
      final saved = await provider.saveWeekly('user_1');

      expect(saved, isFalse);
      expect(
        provider.errorMessage,
        'Aynı gün içindeki saat aralıkları çakışamaz.',
      );
      expect(api.requests, hasLength(1));
    },
  );

  test('bitişi başlangıçtan sonra olmayan aralık PUT edilmez', () async {
    final api = FakeApi(
      handler: (_) => const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': _loadedAvailability},
      ),
    );
    final provider = providerFor(api);
    await provider.load('user_1');

    provider.replaceDaySlots('user_1', AvailabilityDay.monday, const [
      AvailabilitySlot(
        day: AvailabilityDay.monday,
        startTime: '17:00',
        endTime: '09:00',
      ),
    ]);

    expect(await provider.saveWeekly('user_1'), isFalse);
    expect(
      provider.errorMessage,
      'Bitiş saati başlangıç saatinden sonra olmalı.',
    );
    expect(api.requests, hasLength(1));
  });

  test('farklı günlerde aynı saatler çakışma sayılmaz', () async {
    final api = FakeApi(
      handler: (request) => FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': request.method == 'GET'
              ? _loadedAvailability
              : _savedAvailability,
        },
      ),
    );
    final provider = providerFor(api);
    await provider.load('user_1');

    provider.replaceDaySlots('user_1', AvailabilityDay.monday, const [
      AvailabilitySlot(
        day: AvailabilityDay.monday,
        startTime: '10:00',
        endTime: '18:00',
      ),
    ]);

    expect(await provider.saveWeekly('user_1'), isTrue);
    expect(api.requests, hasLength(2));
  });

  test('tarih istisnası eklenip silinebilir', () async {
    final api = FakeApi(
      handler: (request) {
        if (request.method == 'GET') {
          return const FakeApiResponse(
            statusCode: 200,
            body: {'success': true, 'data': _loadedAvailability},
          );
        }
        if (request.method == 'PUT') {
          return FakeApiResponse(
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'id': 'exception_2',
                'date': _futureIsoDate,
                'available': true,
                'note': 'Fazladan çalışabilirim',
              },
            },
          );
        }
        return const FakeApiResponse(statusCode: 200, body: {'success': true});
      },
    );
    final provider = providerFor(api);
    await provider.load('user_1');

    expect(
      await provider.saveException(
        userId: 'user_1',
        date: _futureDate,
        available: true,
        note: 'Fazladan çalışabilirim',
      ),
      isTrue,
    );
    expect(provider.availability?.exceptions, hasLength(2));

    expect(await provider.deleteException('user_1', 'exception_2'), isTrue);
    expect(
      provider.availability?.exceptions.map((item) => item.id),
      isNot(contains('exception_2')),
    );
  });

  test('ilk yükleme tamamlanmadan boş haftayı PUT etmez', () async {
    final loadResponse = Completer<FakeApiResponse>();
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? loadResponse.future
          : const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': _savedAvailability},
            ),
    );
    final provider = providerFor(api);

    final loading = provider.load('user_1');
    expect(await provider.saveWeekly('user_1'), isFalse);

    loadResponse.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': _loadedAvailability},
      ),
    );
    await loading;

    expect(api.requests.map((request) => request.method), ['GET']);
  });

  test('çıkış sırasında dönen kaydetme yanıtı durumu geri doldurmaz', () async {
    final saveResponse = Completer<FakeApiResponse>();
    final api = FakeApi(
      handler: (request) => request.method == 'GET'
          ? const FakeApiResponse(
              statusCode: 200,
              body: {'success': true, 'data': _loadedAvailability},
            )
          : saveResponse.future,
    );
    final provider = providerFor(api);
    await provider.load('user_1');

    final saving = provider.saveWeekly('user_1');
    provider.clear();
    saveResponse.complete(
      const FakeApiResponse(
        statusCode: 200,
        body: {'success': true, 'data': _savedAvailability},
      ),
    );

    expect(await saving, isFalse);
    expect(provider.availability, isNull);
    expect(provider.isSaving, isFalse);
  });
}
