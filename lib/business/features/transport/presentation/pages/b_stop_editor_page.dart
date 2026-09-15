import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/widgets/b_info_notice.dart';
import 'package:koala/business/features/home/presentation/widgets/b_selection_field.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/confirmed_address_field.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// `/business/transport-stop` rotasının `extra`'sı.
class BStopEditorArgs {
  const BStopEditorArgs({required this.stop, this.jobStart});

  /// Düzenlenecek durak; sayfa kopyası üzerinde çalışıyor, kaydedince
  /// kopyayı döndürüyor.
  final StopDraft stop;

  /// İşin başlangıcı; saat seçicinin varsayılan günü ve saati.
  final DateTime? jobStart;
}

/// Tek durağın düzenleyicisi (is-koala/koala#197): etiket, kalkış saati ve
/// harita-önce adres.
///
/// Kaydedince [StopDraft] ile kapanıyor; geri çıkınca hiçbir şey
/// değişmiyor. Adres mevcut akışla seçiliyor (`/pick-address`,
/// `ConfirmedAddress`); var olan durakta adres yeniden seçilmezse gövdeye
/// gitmiyor ve sunucu eskisini koruyor.
class BStopEditorPage extends StatefulWidget {
  const BStopEditorPage({super.key, required this.args});

  final BStopEditorArgs args;

  @override
  State<BStopEditorPage> createState() => _BStopEditorPageState();
}

class _BStopEditorPageState extends State<BStopEditorPage> {
  /// Kalkış saatinin varsayılanı: işin başlangıcından bu kadar önce.
  static const Duration _defaultLeadBeforeJob = Duration(hours: 1);

  /// İş başlangıcı bilinmiyorsa seçici bugünden bir gün sonra açılıyor.
  static const Duration _defaultStartOffset = Duration(days: 1);

  late final StopDraft _stop = widget.args.stop.copy();
  late final _labelController = TextEditingController(text: _stop.label);

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final jobStart = widget.args.jobStart;
    final base =
        _stop.scheduledAt ??
        (jobStart != null
            ? jobStart.subtract(_defaultLeadBeforeJob)
            : now.add(_defaultStartOffset));
    final firstDate = DateTime(now.year, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: base.isBefore(firstDate) ? firstDate : base,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;

    setState(() {
      _stop.scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickAddress() async {
    final picked = await context.push<ConfirmedAddress>(
      '/pick-address',
      extra: _stop.addressForMap,
    );
    if (picked == null || !mounted) return;
    setState(() => _stop.pickedAddress = picked);
  }

  void _save() {
    _stop.label = _labelController.text;
    final error = _stop.validate();
    if (error != null) {
      // Durak doğrulaması "durağın ..." diye küçük harfle başlıyor; servis
      // düzenleyicisi adın önüne koyuyor. Burada tek başına yazılıyor.
      AppToast.error(context, _capitalize(error));
      return;
    }
    context.pop(_stop);
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

  @override
  Widget build(BuildContext context) {
    final seats = _stop.seatsTaken;

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: _stop.isNew ? 'Durak Ekle' : 'Durağı Düzenle'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _save,
        title: 'Durağı Kaydet',
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
                      'Bu durağı $seats çalışan seçti. Adresi ya da saati '
                      'değiştirirseniz bilgilendirilirler.',
                ),
                const SizedBox(height: AppSizes.spaceMedium),
              ],
              MyTextfield(
                labelText: 'Durak adı (ör. Kadıköy İskele)',
                controller: _labelController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              BSelectionField(
                key: const ValueKey('b-stop-time'),
                label: 'Kalkış saati *',
                value: _stop.scheduledAt?.asShortDateTime,
                placeholder: 'Tarih ve saat seçin',
                onTap: _pickTime,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              // Var olan durakta kayıttaki adres ön dolum olarak gösteriliyor
              // (`fromCanonical`); pinsiz eski kayıt yalnız metniyle kalıyor.
              ConfirmedAddressField(
                key: const ValueKey('b-stop-address'),
                value: _stop.addressForMap,
                label: 'Durak adresi *',
                placeholder: _stop.addressSummary ?? 'Haritadan seçin',
                onTap: _pickAddress,
              ),
              const SizedBox(height: AppSizes.navBarClearance),
            ],
          ),
        ),
      ),
    );
  }
}
