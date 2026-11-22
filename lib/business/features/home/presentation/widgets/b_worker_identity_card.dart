import 'package:material_ui/material_ui.dart';
import 'package:koala/business/features/home/models/worker_identity.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Sigorta bildirimi için açılan kimlik bilgileri. Kendi state'i yok, süre ve
/// silme sayfada: kart bellekte kopya bırakmasın. TCKN tek dokunuşla
/// kopyalanır; elle yazılan 11 hane en sık hata kaynağı.
class BWorkerIdentityCard extends StatelessWidget {
  const BWorkerIdentityCard({
    super.key,
    required this.identity,
    required this.onCopyIdentityNumber,
    required this.onHide,
  });

  final WorkerIdentity identity;

  final VoidCallback onCopyIdentityNumber;

  final VoidCallback onHide;

  /// Boş gelen alan da çizilir ki neyin gelmediği görünsün.
  static const String _unknown = '—';

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
            // Ekran okuyucu 11 haneyi sayı gibi okumasın; `liveRegion` yok, her
            // çizimde yeniden duyurulmasın.
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
