/// Haftalık müsaitlik şablonunda kullanılan gün.
///
/// Backend kodu yalnız JSON sınırında [code] üzerinden çevrilir. Arayüz ve
/// durum modülü günleri dizeyle değil bu domain tipiyle taşır.
enum AvailabilityDay {
  monday('MONDAY', 'Pazartesi', 1),
  tuesday('TUESDAY', 'Salı', 2),
  wednesday('WEDNESDAY', 'Çarşamba', 3),
  thursday('THURSDAY', 'Perşembe', 4),
  friday('FRIDAY', 'Cuma', 5),
  saturday('SATURDAY', 'Cumartesi', 6),
  sunday('SUNDAY', 'Pazar', 7);

  const AvailabilityDay(this.code, this.label, this.order);

  final String code;
  final String label;
  final int order;

  static AvailabilityDay fromCode(Object? value) {
    return AvailabilityDay.values.firstWhere(
      (day) => day.code == value,
      orElse: () => throw FormatException('Bilinmeyen müsaitlik günü: $value'),
    );
  }
}
