import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/academic_reference.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Üniversite / fakülte / bölüm seçtiren aranabilir liste.
///
/// Açılır liste kullanılmadı: Türkiye'de iki yüzün üzerinde üniversite var
/// ve `DropdownButton` o uzunlukta kullanılamıyor — aranmadan doğru kaydı
/// bulmak mümkün değil.
class AcademicPickerSheet extends StatefulWidget {
  const AcademicPickerSheet({
    super.key,
    required this.title,
    required this.items,
    this.selected,
  });

  final String title;
  final List<AcademicReference> items;
  final AcademicReference? selected;

  /// Sheet'i açar; seçim yapılırsa kaydı, vazgeçilirse `null` döner.
  static Future<AcademicReference?> show(
    BuildContext context, {
    required String title,
    required List<AcademicReference> items,
    AcademicReference? selected,
  }) {
    return AppBottomSheet.show<AcademicReference>(
      context,
      builder: (_) =>
          AcademicPickerSheet(title: title, items: items, selected: selected),
    );
  }

  @override
  State<AcademicPickerSheet> createState() => _AcademicPickerSheetState();
}

class _AcademicPickerSheetState extends State<AcademicPickerSheet> {
  final TextEditingController _query = TextEditingController();

  /// Listenin yüksekliği; sheet'in ekranı kaplamaması için sabit.
  static const double _listHeight = 360;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Aramada büyük/küçük harf ve Türkçe karakter ayrımı yapılmıyor:
  /// kullanıcı "bogazici" yazınca "Boğaziçi" bulunmalı.
  List<AcademicReference> get _filtered {
    final query = _fold(_query.text);
    if (query.isEmpty) return widget.items;

    return widget.items
        .where((item) => _fold(item.name).contains(query))
        .toList();
  }

  static const Map<String, String> _foldings = {
    'ı': 'i',
    'İ': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
  };

  static String _fold(String value) {
    var folded = value.toLowerCase();
    for (final entry in _foldings.entries) {
      folded = folded.replaceAll(entry.key, entry.value);
    }
    return folded;
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return AppBottomSheet(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MyTextfield(
            labelText: 'Ara',
            controller: _query,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSizes.space),
          SizedBox(
            height: _listHeight,
            child: items.isEmpty
                ? Center(
                    child: Text(
                      'Sonuç yok',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => _tile(items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Satır `ListTile` değil: `AppBottomSheet`'in renkli kabuğu araya
  /// girdiği için mürekkep efekti görünmüyor ve Flutter assert düşürüyor.
  /// Projedeki bütün dokunulabilir satırlar bu yüzden `Material` +
  /// `InkWell` — `ThemeModeSheet._option` ile aynı kurgu.
  Widget _tile(AcademicReference item) {
    final isSelected = item == widget.selected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: () => Navigator.pop(context, item),
        child: Padding(
          padding: AppPadding.tileTall,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : null,
                    color: isSelected ? context.accentColor : null,
                  ),
                ),
              ),
              if (isSelected)
                AppIcon(
                  AppIcons.check,
                  color: context.accentColor,
                  size: AppSizes.icon,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
