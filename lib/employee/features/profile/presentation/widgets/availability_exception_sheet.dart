import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/product/models/availability_exception.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/sheet_switch_row.dart';

typedef AvailabilityExceptionInput = ({
  DateTime date,
  bool available,
  String? note,
});

/// Tek bir tarihin haftalık şablondan farklı çalışmasını düzenleyen sheet.
class AvailabilityExceptionSheet extends StatefulWidget {
  const AvailabilityExceptionSheet({super.key, this.initial});

  final AvailabilityException? initial;

  static Future<AvailabilityExceptionInput?> show(
    BuildContext context, {
    AvailabilityException? initial,
  }) {
    return AppBottomSheet.show<AvailabilityExceptionInput>(
      context,
      builder: (_) => AvailabilityExceptionSheet(initial: initial),
    );
  }

  @override
  State<AvailabilityExceptionSheet> createState() =>
      _AvailabilityExceptionSheetState();
}

class _AvailabilityExceptionSheetState
    extends State<AvailabilityExceptionSheet> {
  static const int _maximumNoteLength = 255;

  late DateTime _date;
  late bool _available;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _date = DateUtils.dateOnly(widget.initial?.date ?? DateTime.now());
    _available = widget.initial?.available ?? false;
    _noteController = TextEditingController(text: widget.initial?.note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppBottomSheet(
        title: widget.initial == null
            ? 'Tarih İstisnası Ekle'
            : 'Tarih İstisnasını Düzenle',
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dateField(),
              const SizedBox(height: AppSizes.spaceMedium),
              SheetSwitchRow(
                title: _available
                    ? 'Bu tarihte çalışabilirim'
                    : 'Bu tarihte çalışamam',
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              TextField(
                key: const ValueKey('availability-exception-note'),
                controller: _noteController,
                maxLines: 3,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_maximumNoteLength),
                ],
                decoration: InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.innerCircular,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.innerCircular,
                    borderSide: BorderSide(color: context.accentColor),
                  ),
                ),
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              MyButton(onPressed: _submit, title: 'Kaydet'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('availability-exception-date'),
        borderRadius: AppRadius.innerCircular,
        onTap: widget.initial == null ? _pickDate : null,
        child: Container(
          width: double.infinity,
          padding: AppPadding.infoTile,
          decoration: BoxDecoration(
            border: Border.all(color: context.dividerColor),
            borderRadius: AppRadius.innerCircular,
          ),
          child: Row(
            children: [
              AppIcon(
                AppIcons.calendar,
                size: AppSizes.iconMedium,
                color: context.accentColor,
              ),
              const SizedBox(width: AppSizes.space),
              Expanded(
                child: Text(
                  _date.asShortDate,
                  style: context.textTheme.bodyMedium,
                ),
              ),
              if (widget.initial == null)
                AppIcon(
                  AppIcons.arrowRight,
                  size: AppSizes.iconSmall,
                  color: context.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(9999, 12, 31),
      helpText: 'İstisna tarihini seç',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  void _submit() {
    final note = _noteController.text.trim();
    Navigator.pop<AvailabilityExceptionInput>(context, (
      date: _date,
      available: _available,
      note: note.isEmpty ? null : note,
    ));
  }
}
