/// `/legal/agreements` yanıtındaki sözleşme sürümü.
///
/// Kayıt tamamlanırken zorunlu olanların hepsi onaylanmış olmalı; backend
/// eksik onayla kaydı reddediyor.
class AgreementVersion {
  const AgreementVersion({
    required this.id,
    required this.type,
    required this.version,
    required this.locale,
    required this.mandatory,
    this.contentUrl,
    this.effectiveFrom,
  });

  final String id;

  /// Sözleşme tipi (`TERMS_OF_SERVICE`, `PRIVACY_POLICY` ...). Bilinmeyen bir
  /// tip gelirse [AgreementType.unknown] olur; ekran yine de çizilir.
  final AgreementType type;

  final String version;

  final String locale;

  /// Onaylanması zorunlu mu.
  final bool mandatory;

  /// Sözleşme metninin public HTTPS adresi. Dolu ve geçerliyse başlık
  /// harici tarayıcıda açılabilir.
  final String? contentUrl;

  final DateTime? effectiveFrom;

  factory AgreementVersion.fromJson(Map<String, dynamic> json) {
    final effectiveFrom = json['effectiveFrom'] as String?;

    return AgreementVersion(
      id: json['id'] as String,
      type: AgreementTypeParsing.fromCode(json['type'] as String?),
      version: json['version'] as String? ?? '',
      locale: json['locale'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      contentUrl: json['contentUrl'] as String?,
      effectiveFrom: effectiveFrom == null
          ? null
          : DateTime.tryParse(effectiveFrom),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.code,
      'version': version,
      'locale': locale,
      'mandatory': mandatory,
      'contentUrl': contentUrl,
      'effectiveFrom': effectiveFrom?.toIso8601String(),
    };
  }
}

/// Backend'in `AgreementType` enum'unun karşılığı.
enum AgreementType {
  termsOfService('TERMS_OF_SERVICE'),
  privacyPolicy('PRIVACY_POLICY'),
  distanceServiceContract('DISTANCE_SERVICE_CONTRACT'),
  explicitConsent('EXPLICIT_CONSENT'),
  commercialMessage('COMMERCIAL_MESSAGE'),

  /// Backend yeni bir tip eklerse uygulama çökmesin diye.
  unknown('UNKNOWN');

  const AgreementType(this.code);

  /// Backend'in gönderdiği değer.
  final String code;

  /// Onay kutusunun yanında yazan cümle.
  ///
  /// Her tip için ayrı ayrı yazıldı; Türkçe ek uyumu tek bir şablonla doğru
  /// üretilemiyor.
  String get consentLabel {
    switch (this) {
      case AgreementType.termsOfService:
        return "Kullanım Koşulları'nı okudum, kabul ediyorum.";
      case AgreementType.privacyPolicy:
        return "Gizlilik Politikası'nı okudum, kabul ediyorum.";
      case AgreementType.distanceServiceContract:
        return "Mesafeli Hizmet Sözleşmesi'ni okudum, kabul ediyorum.";
      case AgreementType.explicitConsent:
        return "Açık Rıza Metni'ni okudum, onay veriyorum.";
      case AgreementType.commercialMessage:
        return 'Kampanya ve duyurular için ticari ileti almak istiyorum.';
      case AgreementType.unknown:
        return 'Sözleşmeyi okudum, kabul ediyorum.';
    }
  }

  /// Onay kutusunda görünen ad.
  String get displayName {
    switch (this) {
      case AgreementType.termsOfService:
        return 'Kullanım Koşulları';
      case AgreementType.privacyPolicy:
        return 'Gizlilik Politikası';
      case AgreementType.distanceServiceContract:
        return 'Mesafeli Hizmet Sözleşmesi';
      case AgreementType.explicitConsent:
        return 'Açık Rıza Metni';
      case AgreementType.commercialMessage:
        return 'Ticari İleti İzni';
      case AgreementType.unknown:
        return 'Sözleşme';
    }
  }
}

extension AgreementTypeParsing on AgreementType {
  static AgreementType fromCode(String? code) {
    return AgreementType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => AgreementType.unknown,
    );
  }
}
