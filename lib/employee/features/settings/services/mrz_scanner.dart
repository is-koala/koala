import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';

/// Kimlik kartının **arka yüzündeki** MRZ'yi kamerayla okur.
///
/// İki parça var ve ikisi de burada değil:
/// - **OCR** `google_mlkit_text_recognition` — bu paket **genel metin
///   tanıma**, MRZ ayrıştırıcı değil. Ne yaptığını sanıp TD1 beklemek en
///   sık yapılan hata.
/// - **Ayrıştırma ve kontrol hanesi doğrulaması** [MrzKey]'de, saf Dart.
///
/// Görüntü `image_picker` ile alınıyor. Yeni bir kamera paketi eklenmedi:
/// `image_picker` zaten bağımlılık listesinde ve tek karelik bir çekim bu
/// akış için yeterli — canlı akış taraması ayrı bir iş.
class MrzScanner {
  MrzScanner({
    ImagePicker? picker,
    TextRecognizer? recognizer,
    this.recognitionTimeout = const Duration(seconds: 30),
    bool? usesDownloadableModel,
  }) : _picker = picker ?? ImagePicker(),
       _recognizer =
           recognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
       _usesDownloadableModel =
           usesDownloadableModel ??
           defaultTargetPlatform == TargetPlatform.android;

  final ImagePicker _picker;
  final TextRecognizer _recognizer;
  final bool _usesDownloadableModel;

  /// Play Services modelinin ilk kullanımda hazırlanmasını bekleme sınırı.
  ///
  /// Model indirilemezse platform çağrısı yanıtsız kalabilir. Otuz saniye ilk
  /// indirmeye alan tanırken kullanıcıyı sonsuz yüklemede bırakmaz.
  final Duration recognitionTimeout;

  /// Kartın arka yüzünü çekip MRZ'yi ayrıştırır.
  ///
  /// Kullanıcı çekimden vazgeçerse `null` döner — bu bir hata değil.
  /// Okuma yapılıp da MRZ çıkarılamazsa [ChipReadException] yükselir
  /// ([ChipReadFailure.mrzUnreadable]); kontrol hanesi tutmayan bir tarama
  /// da buraya düşer, çünkü yanlış anahtarla çipe gitmek kullanıcıya
  /// anlaşılmaz bir "kart okunamadı" gösterirdi.
  Future<MrzKey?> scanCardBack() async {
    final XFile? photo;
    try {
      photo = await _picker.pickImage(
        source: ImageSource.camera,
        // Arka kamera: kart telefonun arkasına tutuluyor.
        preferredCameraDevice: CameraDevice.rear,
        // MRZ küçük punto; küçültmek satırları okunmaz hâle getiriyor, o
        // yüzden çözünürlük kırpılmıyor.
        imageQuality: 100,
      );
    } on Object catch (error) {
      throw ChipReadException(ChipReadFailure.cameraDenied, cause: error);
    }

    if (photo == null) return null;
    return recognize(photo.path);
  }

  /// Verilen görüntüden MRZ'yi çıkarır.
  ///
  /// Ayrı bir metot çünkü tarama yolunun çekim dışındaki yarısı budur ve
  /// hazır bir dosyayla da çağrılabilmesi gerekiyor.
  Future<MrzKey> recognize(String imagePath) async {
    final RecognizedText recognized;
    try {
      recognized = await _recognizer
          .processImage(InputImage.fromFilePath(imagePath))
          .timeout(recognitionTimeout);
    } on TimeoutException catch (error) {
      throw ChipReadException(ChipReadFailure.ocrTimedOut, cause: error);
    } on PlatformException catch (error) {
      if (_isModelDeliveryFailure(error)) {
        // Paketlenmeyen model ağ ya da Play Services yüzünden hazırlanamadı.
        // Görüntünün okunup MRZ üretmemesinden farklı bir çözümü var.
        throw ChipReadException(
          ChipReadFailure.ocrModelUnavailable,
          cause: error,
        );
      }
      throw ChipReadException(ChipReadFailure.mrzUnreadable, cause: error);
    } on Object catch (error) {
      throw ChipReadException(ChipReadFailure.mrzUnreadable, cause: error);
    }

    if (recognized.text.trim().isEmpty && _usesDownloadableModel) {
      // İndirilebilir Android modeli kurulurken ilk istek boş sonuç verebilir.
      // Eklenti bu durumu boş bir görüntüden ayırmadığı için yanlış bir kesinlik
      // vermek yerine kullanıcıya iki kurtarma yolunu da sunuyoruz.
      throw const ChipReadException(ChipReadFailure.ocrUnavailableOrUnreadable);
    }

    final key = MrzKey.parseTd1(recognized.text);
    if (key == null) {
      throw const ChipReadException(ChipReadFailure.mrzUnreadable);
    }
    return key;
  }

  /// Eklenti bütün ML Kit hatalarını aynı `TextRecognizerError` koduyla
  /// döndürüyor. Bu yüzden yalnız model/modül teslimini açıkça söyleyen
  /// mesajlar indirme hatasıdır; bozuk görüntü gibi diğer yerel hatalar
  /// mevcut MRZ-okunamadı davranışında kalır.
  static bool _isModelDeliveryFailure(PlatformException error) {
    if (error.code != 'TextRecognizerError') return false;

    final message = (error.message ?? '').toLowerCase();
    if (message.contains('google play services')) return true;

    final namesModel = message.contains('model') || message.contains('module');
    final describesDelivery =
        message.contains('download') ||
        message.contains('not available') ||
        message.contains('unavailable') ||
        message.contains('cannot load') ||
        message.contains('failed to load');
    return namesModel && describesDelivery;
  }

  /// Yerel tanıyıcıyı kapatır. Ekran kapanırken çağrılmalı; açık kalan
  /// tanıyıcı yerli tarafta bellek tutuyor.
  Future<void> dispose() => _recognizer.close();
}
