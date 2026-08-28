import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Dokununca bir seçici açan, `MyTextfield` görünümündeki alan.
///
/// İlan oluşturma ekranında yazıyla değil seçimle doldurulan alanlar için:
/// il, ilçe, tarih, harita konumu. `InputDecorator` kullanılıyor ki çerçeve,
/// etiket ve iç boşluk metin alanlarıyla birebir aynı dursun.
class BSelectionField extends StatelessWidget {
  const BSelectionField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.enabled = true,
    this.isLoading = false,
    this.icon,
    this.iconColor,
  });

  /// Alanın üstündeki etiket.
  final String label;

  /// Seçili değer; boşsa [placeholder] soluk çiziliyor.
  final String? value;

  final String? placeholder;

  final VoidCallback onTap;

  /// Kapalıyken dokunulamıyor ve soluk çiziliyor: önce başka bir alanın
  /// doldurulması gerekiyorsa (ilçe için il gibi).
  final bool enabled;

  /// Seçenekler hâlâ geliyor mu. Açıkken sağda küçük bir gösterge dönüyor.
  final bool isLoading;

  /// Değerin solunda gösterilen ikon. Kategori gibi görsel karşılığı olan
  /// seçimlerde alan, sheet'teki satırla aynı şeyi göstersin diye.
  final AppIconData? icon;

  /// [icon]'un rengi; verilmezse tema vurgusu.
  final Color? iconColor;

  /// Ok ve gösterge aynı genişlikte dursun diye sabit.
  static const double _trailingSize = AppSizes.iconMedium;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: enabled && !isLoading ? onTap : null,
      borderRadius: AppRadius.primaryCircular,
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: context.textTheme.bodyLarge?.copyWith(
            color: context.textSecondary,
          ),
          enabled: enabled,
          border: const OutlineInputBorder(
            borderRadius: AppRadius.primaryCircular,
          ),
          contentPadding: AppPadding.field,
          isDense: true,
          suffixIcon: SizedBox(
            width: _trailingSize,
            height: _trailingSize,
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(AppSizes.spaceTiny),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.accentColor,
                      ),
                    ),
                  )
                : Icon(
                    Icons.keyboard_arrow_down,
                    size: _trailingSize,
                    color: context.textTertiary,
                  ),
          ),
        ),
        child: Row(
          children: [
            if (icon != null && hasValue) ...[
              AppIcon(
                icon!,
                size: AppSizes.iconMedium,
                color: iconColor ?? context.accentColor,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
            ],
            Expanded(
              child: Text(
                hasValue ? value! : (placeholder ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: hasValue ? context.textPrimary : context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
