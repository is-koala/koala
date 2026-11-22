import 'package:material_ui/material_ui.dart';

/// İşveren formlarının tarih + saat seçimi: önce gün, sonra saat; biri iptal
/// edilirse `null`. Geçmiş bir saate ilan ya da servis açılmasın diye bugünden
/// öncesi kapalı.
abstract final class DateTimePicking {
  static const Duration defaultStartOffset = Duration(days: 1);

  static const Duration horizon = Duration(days: 365);

  /// Geçmişe düşen açılış değeri bugüne çekilir.
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
