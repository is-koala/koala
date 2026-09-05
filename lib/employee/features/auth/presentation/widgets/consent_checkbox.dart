import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/employee/features/auth/services/legal_document_browser.dart';

/// Kayıt ekranındaki tek bir sözleşme onayı.
///
/// Zorunlu onaylar sonuna kırmızı bir yıldız alıyor; metnin tamamı
/// tıklanabilir, böylece küçük kutuyu tutturmak gerekmiyor.
class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isMandatory = false,
    this.linkText,
    this.contentUrl,
    this.legalBrowser,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isMandatory;

  /// [label] içinde bağlantı olarak çizilecek sözleşme adı.
  final String? linkText;

  /// Backend'in sözleşme sürümü için verdiği içerik adresi.
  final String? contentUrl;

  /// Gerçek tarayıcı yerine test sınırı enjekte edilebilmesini sağlar.
  final LegalDocumentBrowser? legalBrowser;

  @override
  Widget build(BuildContext context) {
    final browser = legalBrowser ?? LegalDocumentBrowser();
    final link = linkText;
    final linkStart = link == null ? -1 : label.indexOf(link);
    final hasLink = link != null && browser.canOpen(contentUrl);
    final baseStyle = context.textTheme.bodySmall?.copyWith(
      color: context.textSecondary,
    );
    WidgetSpan linkedText() => WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => browser.open(contentUrl),
        child: Text(
          link!,
          style: baseStyle?.copyWith(
            color: context.accentColor,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );

    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: value,
            onChanged: (isChecked) => onChanged(isChecked ?? false),
            activeColor: context.accentColor,
            checkColor: context.onAccentColor,
            side: BorderSide(color: context.dividerColor),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  if (hasLink && linkStart >= 0) ...[
                    TextSpan(text: label.substring(0, linkStart)),
                    linkedText(),
                    TextSpan(text: label.substring(linkStart + link.length)),
                  ] else if (hasLink) ...[
                    linkedText(),
                    TextSpan(text: ': $label'),
                  ] else
                    TextSpan(text: label),
                  if (isMandatory)
                    TextSpan(
                      text: ' *',
                      style: baseStyle?.copyWith(color: AppColors.danger),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
        ],
      ),
    );
  }
}
