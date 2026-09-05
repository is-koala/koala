import 'package:flutter/material.dart';
import 'package:koala/employee/features/auth/models/agreement_version.dart';
import 'package:koala/employee/features/auth/services/legal_document_browser.dart';
import 'package:koala/employee/features/auth/services/legal_service.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';

/// Giriş ve kayıt sayfalarının en altındaki kullanım şartları satırı.
///
/// İki sayfada da aynı; metin `RichText` çünkü cümlenin ortasındaki iki
/// bağlantı ayrı ayrı tıklanabilir olmalı.
class AuthLegalFooter extends StatefulWidget {
  const AuthLegalFooter({super.key, this.legalService, this.legalBrowser});

  /// Yürürlükteki sözleşmeleri getiren sınır; widget testlerinde sahtesi
  /// verilebilir.
  final LegalService? legalService;

  /// Yasal metni açan sınır; widget testlerinde gerçek tarayıcıyı açmaz.
  final LegalDocumentBrowser? legalBrowser;

  @override
  State<AuthLegalFooter> createState() => _AuthLegalFooterState();
}

class _AuthLegalFooterState extends State<AuthLegalFooter> {
  late final LegalService _legalService;
  late final LegalDocumentBrowser _legalBrowser;

  String? _termsUrl;
  String? _privacyUrl;

  @override
  void initState() {
    super.initState();
    _legalService = widget.legalService ?? LegalService();
    _legalBrowser = widget.legalBrowser ?? LegalDocumentBrowser();
    _loadAgreements();
  }

  Future<void> _loadAgreements() async {
    try {
      final agreements = await _legalService.fetchCurrentAgreements();
      if (!mounted) return;
      setState(() {
        _termsUrl = _contentUrlFor(agreements, AgreementType.termsOfService);
        _privacyUrl = _contentUrlFor(agreements, AgreementType.privacyPolicy);
      });
    } on ApiException {
      // Sözleşme listesi alınamazsa metin düz kalır; ölü link çizilmez.
    }
  }

  String? _contentUrlFor(
    List<AgreementVersion> agreements,
    AgreementType type,
  ) {
    for (final agreement in agreements) {
      if (agreement.type == type &&
          _legalBrowser.canOpen(agreement.contentUrl)) {
        return agreement.contentUrl;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = context.textTheme.labelSmall?.copyWith(
      color: context.textSecondary,
      height: 1.5,
    );

    return Padding(
      padding: AppPadding.authFooter,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'Devam ederek '),
            _legalText(
              context,
              label: 'Kullanım Şartları',
              contentUrl: _termsUrl,
              baseStyle: baseStyle,
            ),
            const TextSpan(text: ' ve '),
            _legalText(
              context,
              label: 'Gizlilik Politikası',
              contentUrl: _privacyUrl,
              baseStyle: baseStyle,
            ),
            const TextSpan(text: "'nı kabul etmiş olursunuz."),
          ],
        ),
      ),
    );
  }

  InlineSpan _legalText(
    BuildContext context, {
    required String label,
    required String? contentUrl,
    required TextStyle? baseStyle,
  }) {
    final linkStyle = baseStyle?.copyWith(
      color: context.accentColor,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: contentUrl == null
          ? Text(label, style: baseStyle)
          : GestureDetector(
              onTap: () => _legalBrowser.open(contentUrl),
              child: Text(label, style: linkStyle),
            ),
    );
  }
}
