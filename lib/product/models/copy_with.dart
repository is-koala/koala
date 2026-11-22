/// `copyWith`'te "dokunma" ile "temizle"yi ayıran nöbetçi. Süzgeç çipleri tek
/// tek kaldırılabildiği için `copyWith(categoryId: null)` alanı sıfırlamalı; bu
/// parametreler `Object?` ve varsayılanları [unset].
abstract final class CopyWith {
  /// Kimlikle karşılaştırıldığı için `const` ve tekil.
  static const Object unset = Object();

  /// `Object?` tip hatasını yakalamıyor: `copyWith(minSalary: 100)` çalışma
  /// anında patlardı; sayısal dönüştürme burada.
  static T? pick<T>(Object? candidate, T? current) {
    if (identical(candidate, unset)) return current;
    if (candidate is int && <double?>[] is List<T?>) {
      return candidate.toDouble() as T?;
    }
    return candidate as T?;
  }
}
