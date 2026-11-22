import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İkon, başlık ve sağda ok taşıyan menü satırı.
///
/// Tek başına kendi kartını çiziyor. Bir [MyListGroup] içindeyse kart
/// grubun oluyor: satır yalnız içeriğini çiziyor, aralarındaki çizgiyi grup
/// koyuyor.
class MyListTile extends StatelessWidget {
  const MyListTile({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.value,
    this.opensExternally = false,
  });

  final String title;
  final AppIconData icon;
  final VoidCallback? onTap;

  /// Satırın sağında, chevron'dan önce gösterilen mevcut değer. Ayarın o
  /// anki durumunu satırı açmadan görebilmek için (örn. "Sistem").
  final String? value;

  /// Dokunma kullanıcıyı uygulama dışına (tarayıcı, arama, harita, posta)
  /// götürüyorsa `true`: sağdaki ok, sayfa içi geçişin chevron'u yerine
  /// sağ üste bakan oka döner.
  final bool opensExternally;

  @override
  Widget build(BuildContext context) {
    final row = Padding(padding: AppPadding.tileTall, child: _row(context));

    if (_MyListGroupScope.isInside(context)) {
      return InkWell(onTap: onTap, child: row);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          borderRadius: AppRadius.innerCircular,
          onTap: onTap,
          // Zemini ve yarıçapı [Material] çiziyor; satırı sayfadan ayıran
          // şey zemin tonu, çerçeve değil.
          child: row,
        ),
      ),
    );
  }

  Widget _row(BuildContext context) {
    return Row(
      children: [
        AppIcon(icon, color: context.textPrimary),
        const SizedBox(width: AppSizes.spaceMedium),
        Expanded(
          child: Text(
            title,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (value != null) ...[
          Text(
            value!,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
        ],
        // Dokunulmayan satırda ok, olmayan bir yere işaret ederdi.
        if (onTap != null)
          opensExternally
              ? AppIcon(
                  AppIcons.arrowUpRight,
                  size: AppSizes.iconMedium,
                  color: context.textTertiary,
                )
              : Icon(
                  Icons.chevron_right,
                  size: AppSizes.iconMedium,
                  color: context.textTertiary,
                ),
      ],
    );
  }
}

/// [MyListTile]'ları tek kartta, aralarında ince çizgiyle toplayan grup.
///
/// Ayarlar menüsünü konularına ayırmak ve bir sayfadaki ilişkili satırları
/// (şirketin iletişim bilgileri gibi) birlikte göstermek için. [title]
/// verilirse kartın üstünde küçük, sönük bir başlık olarak duruyor.
class MyListGroup extends StatelessWidget {
  const MyListGroup({super.key, this.title, required this.children});

  final String? title;

  /// Genelde [MyListTile]'lar; grubun içindeyken kendi kartlarını çizmiyorlar.
  final List<Widget> children;

  /// Çizgi, ikonun değil başlığın hizasından başlıyor: satır boşluğu + ikon
  /// + ikonla başlık arası.
  static const double _dividerIndent =
      AppSizes.spaceMedium + AppSizes.icon + AppSizes.spaceMedium;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSizes.spaceMedium,
                bottom: AppSizes.spaceSmall,
              ),
              child: Text(
                title,
                style: context.textTheme.labelLarge?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
          Material(
            color: context.tileColor,
            borderRadius: AppRadius.innerCircular,
            clipBehavior: Clip.antiAlias,
            child: _MyListGroupScope(
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: AppSizes.divider,
                        thickness: AppSizes.divider,
                        indent: _dividerIndent,
                        color: context.dividerColor,
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Altındaki [MyListTile]'lara bir grubun içinde olduklarını söylüyor.
class _MyListGroupScope extends InheritedWidget {
  const _MyListGroupScope({required super.child});

  static bool isInside(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_MyListGroupScope>() != null;

  @override
  bool updateShouldNotify(_MyListGroupScope oldWidget) => false;
}
