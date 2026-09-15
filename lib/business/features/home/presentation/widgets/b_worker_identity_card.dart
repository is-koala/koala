import 'package:flutter/material.dart';
import 'package:koala/business/features/home/models/worker_identity.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Sigorta bildirimi için açılan çalışan kimlik bilgileri.
///
/// Atama panelinde, "Kimlik bilgilerini göster" onaylanıp sunucu yanıt
/// verince çiziliyor. Değerleri yalnızca gösterir; süreyi ve silmeyi sayfa
/// tutuyor — kart bellekte kopya bırakmasın diye kendi state'i yok. TCKN
/// tek dokunuşla kopyalanabiliyor: sigorta ekranına elle yazılan 11 hane
/// en sık hata kaynağı.
class BWorkerIdentityCard extends StatelessWidget {
  const BWorkerIdentityCard({
    super.key,
    required this.identity,
    required this.onCopyIdentityNumber,
    required this.onHide,
  });

  final WorkerIdentity identity;

  /// TCKN'yi panoya kopyalar.
  final VoidCallback onCopyIdentityNumber;

  /// Süre dolmadan gizler.
  final VoidCallback onHide;

  /// Değer yoksa yerine yazılan. Ad ya da tarih sunucudan boş gelebilir;
  /// kart alanı yine çizer ki hangi bilginin gelmediği görünsün.
  static const String _unknown = '—';

  /// Etiket sütunu; değerler hizalı dursun diye sabit.
  static const double _labelWidth = 104;

  @override
  Widget build(BuildContext context) {
    final verifiedAt = identity.verifiedAt?.toLocal().asShortDateTime;
    final method = identity.verificationMethod.displayName;
    final verification = switch ((verifiedAt, method)) {
      (null, null) => _unknown,
      (null, final method?) => method,
      (final at?, null) => at,
      (final at?, final method?) => '$at · $method',
    };

    return Container(
      key: const ValueKey('worker-identity-card'),
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                AppIcons.shield,
                size: AppSizes.iconSmall,
                color: context.accentColor,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Expanded(
                child: Text(
                  'Kimlik bilgileri (sigorta için)',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('worker-identity-hide'),
                onPressed: onHide,
                child: const Text('Gizle'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          _row(
            context,
            'Ad Soyad',
            identity.fullName.isEmpty ? _unknown : identity.fullName,
            valueKey: const ValueKey('worker-identity-name'),
          ),
          _row(
            context,
            'TCKN',
            identity.tcIdentityNumber,
            valueKey: const ValueKey('worker-identity-tckn'),
            // Ekran okuyucu 11 haneyi sayı gibi ("on milyar…") okumasın:
            // hane hane, boşluklu. `liveRegion` bilerek yok — kart her
            // yeniden çizimde yeniden duyurulmamalı.
            semanticsLabel: identity.tcIdentityNumber.split('').join(' '),
            trailing: IconButton(
              key: const ValueKey('worker-identity-copy'),
              tooltip: 'TCKN\'yi kopyala',
              visualDensity: VisualDensity.compact,
              onPressed: onCopyIdentityNumber,
              icon: AppIcon(
                AppIcons.copy,
                size: AppSizes.iconSmall,
                color: context.accentColor,
              ),
            ),
          ),
          _row(
            context,
            'Doğum tarihi',
            identity.birthDate?.asShortDate ?? _unknown,
            valueKey: const ValueKey('worker-identity-birth-date'),
          ),
          _row(
            context,
            'Doğrulama',
            verification,
            valueKey: const ValueKey('worker-identity-verification'),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            'Bu görüntüleme kayda geçti ve çalışana bildirildi. Bilgiler '
            'bir dakika sonra ya da sayfadan çıkınca gizlenir.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    required Key valueKey,
    String? semanticsLabel,
    Widget? trailing,
  }) {
    final text = Text(
      value,
      key: valueKey,
      style: context.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceTiny),
      child: Row(
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: semanticsLabel == null
                ? text
                : Semantics(
                    label: semanticsLabel,
                    excludeSemantics: true,
                    child: text,
                  ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
