import 'package:flutter/material.dart';

/// İşveren formlarının tarih + saat seçtirme akışı.
///
/// İlan formunun başlangıç/bitişi ve ulaşım durağının kalkış saati aynı
/// iki adımı yürüyor: önce gün, sonra saat; ikisinden biri iptal edilirse
/// `null` ve çağıranda hiçbir şey değişmiyor. Seçici bugünden öncesini
/// kapatıyor — geçmiş bir saate ilan ya da servis açılmasın.
abstract final class DateTimePicking {
  /// Seçici açılışta ne kadar ileride: yarın.
  static const Duration defaultStartOffset = Duration(days: 1);

  /// Seçilebilen en uzak gün.
  static const Duration horizon = Duration(days: 365);

  /// [initial] seçicinin açılış değeri; yoksa yarın. Geçmişe düşen bir
  /// açılış değeri bugüne çekiliyor.
  static Future<DateTime?> pick(
    BuildContext context, {
    DateTime? initial,
  }) async {
    final now = DateTime.now();
    final base = initial ?? now.add(defaultStartOffset);

    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: now,
      lastDate: now.add(horizon),
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
