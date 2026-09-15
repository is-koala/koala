import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/widgets/b_info_notice.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/business/features/transport/presentation/pages/b_stop_editor_page.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// `/business/transport-shuttle` rotasının `extra`'sı.
class BShuttleEditorArgs {
  const BShuttleEditorArgs({required this.shuttle, this.jobStart});

  /// Düzenlenecek servis; sayfa kopyası üzerinde çalışıyor.
  final ShuttleDraft shuttle;

  /// İşin başlangıcı; durak saat seçicisine geçiyor.
  final DateTime? jobStart;
}

/// Tek servisin düzenleyicisi (is-koala/koala#197): ad, plaka, kapasite,
/// şoför ve sıralı duraklar.
///
/// Kaydedince [ShuttleDraft] ile kapanıyor. Duraklar eklendikleri sırayla
/// gidiyor; sunucu bu sırayı `sortOrder` yapıyor. Koltuğu olan bir durağı
/// silmek "N çalışanın koltuğu düşecek" onayı istiyor — koltuk sunucuda
/// kaydedilince düşüyor, o yüzden uyarı kesin değil ama sayı gerçek.
class BShuttleEditorPage extends StatefulWidget {
  const BShuttleEditorPage({super.key, required this.args});

  final BShuttleEditorArgs args;

  @override
  State<BShuttleEditorPage> createState() => _BShuttleEditorPageState();
}

class _BShuttleEditorPageState extends State<BShuttleEditorPage> {
  late final ShuttleDraft _shuttle = widget.args.shuttle.copy();
  late final _nameController = TextEditingController(text: _shuttle.name);
  late final _plateController = TextEditingController(text: _shuttle.plate);
  late final _capacityController = TextEditingController(
    text: _shuttle.capacity?.toString() ?? '',
  );
  late final _driverNameController = TextEditingController(
    text: _shuttle.driverName,
  );
  late final _driverPhoneController = TextEditingController(
    text: _shuttle.driverPhone,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _capacityController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    super.dispose();
  }

  /// Alanları taslağa yazar; doğrulama ve kaydetme bunu okuyor.
  void _syncFields() {
    _shuttle
      ..name = _nameController.text
      ..plate = _plateController.text
      ..capacity = int.tryParse(_capacityController.text.trim())
      ..driverName = _driverNameController.text
      ..driverPhone = _driverPhoneController.text;
  }

  Future<void> _addStop() => _editStop(null);

  Future<void> _editStop(int? index) async {
    final draft = index == null ? StopDraft() : _shuttle.stops[index];
    final saved = await context.push<StopDraft>(
      BusinessRoutes.transportStop,
      extra: BStopEditorArgs(stop: draft, jobStart: widget.args.jobStart),
    );
    if (saved == null || !mounted) return;
    setState(() {
      if (index == null) {
        _shuttle.stops.add(saved);
      } else {
        _shuttle.stops[index] = saved;
      }
    });
  }

  Future<void> _removeStop(int index) async {
    final stop = _shuttle.stops[index];
    final seats = stop.seatsTaken;
    if (seats > 0) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Durağı sil',
        message:
            '$seats çalışanın koltuğu düşecek; plan kaydedilince yeniden '
            'koltuk seçmeleri istenecek.',
        actionLabel: 'Sil',
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _shuttle.stops.removeAt(index));
  }

  void _save() {
    _syncFields();
    final error = _shuttle.validate();
    if (error != null) {
      AppToast.error(context, error);
      return;
    }
    context.pop(_shuttle);
  }

  @override
  Widget build(BuildContext context) {
    final seats = _shuttle.seatsTaken;
    final direction = _shuttle.direction.displayName;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(
        title: _shuttle.isNew ? '$direction Servisi Ekle' : 'Servisi Düzenle',
      ),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _save,
        title: 'Servisi Kaydet',
      ),
      body: FormPageBody(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (seats > 0) ...[
                BInfoNotice(
                  message:
                      'Bu serviste $seats koltuk seçildi; kapasite bunun '
                      'altına inemez.',
                ),
                const SizedBox(height: AppSizes.spaceMedium),
              ],
              MyTextfield(
                labelText: 'Servis adı *',
                controller: _nameController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Row(
                children: [
                  Expanded(
                    child: MyTextfield(
                      labelText: 'Plaka',
                      controller: _plateController,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(
                          ShuttleDraft.maxPlateLength,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceMedium),
                  Expanded(
                    child: MyTextfield(
                      labelText: 'Kapasite *',
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: 'Şoför adı',
                controller: _driverNameController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: 'Şoför telefonu',
                controller: _driverPhoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              const BInfoNotice(
                message:
                    'Plaka ve şoför bilgisini yalnız bu serviste koltuk seçen '
                    'çalışanlar görür.',
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              Text('Duraklar', style: context.textTheme.titleMedium),
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                'Servisin uğrayacağı sırayla ekleyin.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.space),
              for (var index = 0; index < _shuttle.stops.length; index++)
                _stopRow(index),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('b-shuttle-add-stop'),
                  onPressed: _addStop,
                  icon: AppIcon(
                    AppIcons.plus,
                    size: AppSizes.iconSmall,
                    color: context.accentColor,
                  ),
                  label: const Text('Durak ekle'),
                  style: context.accentOutlinedButtonStyle,
                ),
              ),
              const SizedBox(height: AppSizes.navBarClearance),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stopRow(int index) {
    final stop = _shuttle.stops[index];
    final time = stop.scheduledAt?.asShortDateTime ?? 'Saat seçilmedi';
    final address = stop.addressSummary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          key: ValueKey('b-shuttle-stop-$index'),
          borderRadius: AppRadius.innerCircular,
          onTap: () => _editStop(index),
          child: Padding(
            padding: AppPadding.infoTile,
            child: Row(
              children: [
                Text(
                  '${index + 1}',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: context.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stop.displayName} · $time',
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (address != null)
                        Text(
                          address,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      if (stop.seatsTaken > 0)
                        Text(
                          '${stop.seatsTaken} koltuk seçildi',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.accentColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('b-shuttle-remove-stop-$index'),
                  tooltip: 'Durağı sil',
                  onPressed: () => _removeStop(index),
                  icon: AppIcon(
                    AppIcons.delete,
                    size: AppSizes.iconMedium,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
