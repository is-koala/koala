/// Sözleşme sürümü; zorunlu olanların hepsi onaylanmadan backend kaydı
/// reddediyor.
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

  /// Bilinmeyen tip [AgreementType.unknown]; ekran yine çizilir.
  final AgreementType type;

  final String version;

  final String locale;

  final bool mandatory;

  /// Doluysa başlık harici tarayıcıda açılabilir.
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

enum AgreementType {
  termsOfService('TERMS_OF_SERVICE'),
  privacyPolicy('PRIVACY_POLICY'),
  distanceServiceContract('DISTANCE_SERVICE_CONTRACT'),
  explicitConsent('EXPLICIT_CONSENT'),
  commercialMessage('COMMERCIAL_MESSAGE'),

  unknown('UNKNOWN');

  const AgreementType(this.code);

  final String code;

  /// Türkçe ek uyumu tek şablonla doğru üretilemediği için her tip ayrı.
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
