/// Bir Huge Icons ikonunun veri tipi.
///
/// hugeicons 1.x ikonları artık `IconData` (font glifi) değil, `HugeIcon`
/// widget'ının SVG'ye çevirdiği ham path listesi olarak veriyor. Tip imzası
/// (`List<List<dynamic>>`) okunaksız olduğu için kod içinde bu takma ad
/// kullanılıyor; paket bir gün tekrar değişirse tek dosya güncelleniyor.
typedef AppIconData = List<List<dynamic>>;
