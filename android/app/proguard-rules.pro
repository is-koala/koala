# R8 / ProGuard kuralları.
#
# Dosya `google_mlkit_text_recognition` yüzünden açıldı: eklenti Latin'in
# yanında Çince, Devanagari, Japonca ve Korece tanıyıcıları da **çağırıyor**
# ama o modeller ayrı paketlerde ve biz onları bağımlılık olarak almıyoruz.
# Kural olmadan release build'i `minify...WithR8` adımında **düşüyor** —
# debug build'i sorunsuz geçtiği için ancak yayına çıkarken fark edilirdi.
#
# Modelleri eklemek yerine uyarıyı susturuyoruz: MRZ Latin alfabesinde ve
# kullanılmayan dört model APK'yı gereksiz büyütürdü.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
