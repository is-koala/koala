import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Bir listeden tek seçim yaptıran bottom sheet.
///
/// İlan oluşturma ekranındaki bütün açılır alanlar bunu kullanıyor: kategori,
/// ülke, il, ilçe. Kategori bir zamanlar çip dizisiydi; liste sunucudan
/// geldiği ve büyüyebildiği için diğerleriyle aynı kalıba alındı.
///
/// **`product/` altında ve öneksiz**, çünkü artık çalışan tarafındaki keşfet
/// süzgeci de il ve ilçe seçimini bununla yaptırıyor; `b_` öneki "yalnız
/// işveren tarafı" demek.
///
/// Satırlar `ListTile` değil, [ThemeModeSheet]'teki gibi `Material` + `InkWell`:
/// `AppBottomSheet`'in kabuğu renkli bir `DecoratedBox` ve `ListTile` zeminini
/// en yakın `Material`'a çizdiği için o kabuk zemini gizliyor — Flutter bunu
/// "ListTile background color or ink splashes may be invisible" diye
/// bildiriyor.
class OptionSheet<T> extends StatelessWidget {
  const OptionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.labelOf,
    this.selected,
    this.iconOf,
    this.colorOf,
  });

  /// Sheet'in başlığı.
  final String title;

  final List<T> options;

  /// Satırda yazan ad.
  final String Function(T) labelOf;

  /// Seçili olan; halkalı ve tikli çiziliyor.
  final T? selected;

  /// Satırın solundaki ikon. Verilmezse ikon sütunu hiç çizilmiyor.
  final AppIconData? Function(T)? iconOf;

  /// Satırın vurgu rengi. Verilmezse tema vurgusu kullanılıyor — kategoriler
  /// kendi renkleriyle çizilsin diye açık bırakıldı.
  final Color? Function(T)? colorOf;

  /// Seçili satırın zemin opaklığı.
  static const double _selectedTintAlpha = 0.1;

  /// Seçili satırın halkası; zemin tonu tek başına seçimi anlatmıyor.
  static const double _selectedBorderWidth = 2.0;

  /// Listenin kaplayabileceği en fazla yükseklik oranı. 81 il tam ekranı
  /// doldurmasın, altındaki sayfa görünmeye devam etsin diye.
  static const double _maxHeightRatio = 0.6;

  /// Sheet'i açar ve seçilen değeri döndürür; vazgeçilirse `null`.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<T> options,
    required String Function(T) labelOf,
    T? selected,
    AppIconData? Function(T)? iconOf,
    Color? Function(T)? colorOf,
  }) {
    return AppBottomSheet.show<T>(
      context,
      builder: (_) => OptionSheet<T>(
        title: title,
        options: options,
        labelOf: labelOf,
        selected: selected,
        iconOf: iconOf,
        colorOf: colorOf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title,
      child: Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: context.dynamicHeight(_maxHeightRatio),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (_, index) => _option(context, options[index]),
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, T option) {
    final isSelected = option == selected;
    final accent = colorOf?.call(option) ?? context.accentColor;
    final icon = iconOf?.call(option);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: isSelected
            ? accent.withValues(alpha: _selectedTintAlpha)
            : context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          borderRadius: AppRadius.innerCircular,
          onTap: () => Navigator.pop(context, option),
          child: Container(
            padding: AppPadding.tileTall,
            decoration: BoxDecoration(
              borderRadius: AppRadius.innerCircular,
              border: isSelected
                  ? Border.all(color: accent, width: _selectedBorderWidth)
                  : null,
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  AppIcon(
                    icon,
                    size: AppSizes.iconMedium,
                    color: isSelected ? accent : context.textSecondary,
                  ),
                  const SizedBox(width: AppSizes.spaceMedium),
                ],
                Expanded(
                  child: Text(
                    labelOf(option),
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected ? accent : context.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check, size: AppSizes.iconMedium, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
