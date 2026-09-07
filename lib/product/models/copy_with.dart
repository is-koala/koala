/// `copyWith`'te "dokunma" ile "temizle"yi ayıran nöbetçi ve onu çözen seçici.
///
/// Süzgeç çipleri tek tek kaldırılabildiği için `copyWith(categoryId: null)`
/// çağrısının alanı **sıfırlaması** gerekiyor; sıradan bir `String?`
/// parametrede bu "verilmedi" ile aynı şeye denk düşerdi. Bu yüzden bu deseni
/// kullanan `copyWith` parametreleri `Object?` ve varsayılanları [unset].
///
/// Neden ortak bir yerde: ikili `JobSearchQuery` ve `JobFilterSelection`
/// içinde — `///` yorumu dâhil — kelimesi kelimesine iki kez duruyordu.
/// [pick]'in gövdesi bir hata düzeltmesinin izini taşıyor (aşağıya bakın);
/// kopyaların birinde düzeltilip ötekinde unutulması işten değildi.
abstract final class CopyWith {
  /// "Bu parametre hiç verilmedi" demek. Kimlik karşılaştırmasıyla ayırt
  /// edildiği için `const` ve tekil olmalı.
  static const Object unset = Object();

  /// Nöbetçi parametreler `Object?` olduğu için derleyici tip uyuşmazlığını
  /// yakalayamıyor: `copyWith(minSalary: 100)` sorunsuz derleniyor ama `int`
  /// bir `double?` alana atanamadığı için çalışma anında patlıyordu. Sayısal
  /// alanlarda dönüştürme burada yapılıyor.
  static T? pick<T>(Object? candidate, T? current) {
    if (identical(candidate, unset)) return current;
    if (candidate is int && <double?>[] is List<T?>) {
      return candidate.toDouble() as T?;
    }
    return candidate as T?;
  }
}
