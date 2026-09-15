import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/widgets/b_info_notice.dart';
import 'package:koala/business/features/home/presentation/widgets/b_selection_field.dart';
import 'package:koala/business/features/transport/models/transport_plan_draft.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_editor_page.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/transport_error_codes.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/services/transport_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:koala/product/widgets/option_sheet.dart';

part 'b_transport_plan_pagemodel.dart';

/// `/business/transport-plan` rotasının `extra`'sı.
///
/// İki mod var:
/// - **İlan modu** ([jobId] dolu): sayfa `GET /jobs/{id}/transport-plan` ile
///   açılır (`404` → boş taslak), *Kaydet* `PUT` atar ve sunucunun
///   döndürdüğü [TransportPlan] ile kapanır.
/// - **Taslak modu** ([jobId] boş, ilan oluşturma): sunucuya gidilmez;
///   *Kaydet* [TransportPlanDraft] ile kapanır, ilan açıldıktan sonra form
///   planı yazar.
class BTransportPlanArgs {
  const BTransportPlanArgs({
    this.jobId,
    this.initial,
    this.original,
    this.jobStart,
  });

  final String? jobId;

  /// Açılış taslağı; ilan modunda sunucudan okunan planın kopyası, taslak
  /// modunda formun elindeki taslak. Boşsa sayfa boş taslakla ya da
  /// (ilan modunda) sunucudan okuyarak açılır.
  final TransportPlanDraft? initial;

  /// İlan modunda sunucudaki plan; silme uyarısının koltuk sayısı buradan.
  /// Verilmezse sayfa okuyor.
  final TransportPlan? original;

  /// İşin başlangıcı; durak saat seçicisinin varsayılanı.
  final DateTime? jobStart;
}

/// Ulaşım planı düzenleyicisi (is-koala/koala#197): gidiş/dönüş yöntemi,
/// yol parası, not ve yön başına servis listesi.
class BTransportPlanPage extends StatefulWidget {
  const BTransportPlanPage({super.key, required this.args, this.service});

  final BTransportPlanArgs args;

  /// Testler için; verilmezse üretimdeki tekil servis.
  final TransportService? service;

  @override
  State<BTransportPlanPage> createState() => _BTransportPlanPageState();
}

class _BTransportPlanPageState extends BTransportPlanPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Ulaşım Planı'),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _isLoading || _isSaving ? null : _save,
        title: 'Kaydet',
        isLoading: _isSaving,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FormPageBody(
              child: Padding(
                padding: AppPadding.primaryAll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadError != null) ...[
                      _loadErrorStrip(),
                      const SizedBox(height: AppSizes.spaceMedium),
                    ],
                    _sectionLabel('Yöntem'),
                    const SizedBox(height: AppSizes.spaceMedium),
                    _methodField(ShuttleDirection.outbound),
                    const SizedBox(height: AppSizes.spaceMedium),
                    _methodField(ShuttleDirection.returnTrip),
                    if (_draft.hasCashAllowance) ...[
                      const SizedBox(height: AppSizes.spaceMedium),
                      MyTextfield(
                        key: const ValueKey('b-transport-allowance'),
                        labelText: 'Yol parası tutarı (₺) *',
                        controller: _allowanceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceMedium),
                      MyTextfield(
                        labelText: 'Yol parası notu (ör. gün sonunda elden)',
                        controller: _allowanceNoteController,
                      ),
                      const SizedBox(height: AppSizes.spaceSmall),
                      const BInfoNotice(
                        message:
                            'Yol parası bilgi amaçlıdır; ödeme yolunun '
                            'dışındadır, çalışana elden verirsiniz.',
                      ),
                    ],
                    const SizedBox(height: AppSizes.spaceLarge),
                    _sectionLabel('Ulaşım notu'),
                    const SizedBox(height: AppSizes.spaceMedium),
                    MyTextfield(
                      labelText: 'Atanmış çalışanların göreceği not',
                      controller: _notesController,
                    ),
                    for (final direction in ShuttleDirection.values)
                      if (_draft.usesShuttle(direction)) ...[
                        const SizedBox(height: AppSizes.spaceLarge),
                        _sectionLabel('${direction.displayName} servisleri'),
                        const SizedBox(height: AppSizes.spaceMedium),
                        ..._shuttleList(direction),
                      ],
                    const SizedBox(height: AppSizes.navBarClearance),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionLabel(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  /// Plan okunamadı: form boş açıldı, kaydetmek mevcut planın üstüne
  /// yazar — kullanıcı bunu bilmeli.
  Widget _loadErrorStrip() {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mevcut plan okunamadı: $_loadError. Kaydederseniz plan '
              'buradaki hâliyle yazılır.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          TextButton(onPressed: _loadPlan, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }

  Widget _methodField(ShuttleDirection direction) {
    return BSelectionField(
      key: ValueKey('b-transport-method-${direction.code}'),
      label: '${direction.displayName} yöntemi *',
      value: _draft.methodFor(direction).displayName,
      onTap: () => _pickMethod(direction),
    );
  }

  List<Widget> _shuttleList(ShuttleDirection direction) {
    final shuttles = _draft.shuttlesFor(direction);

    return [
      if (shuttles.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
          child: Text(
            'Henüz servis eklemediniz.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
      for (final shuttle in shuttles) _shuttleCard(shuttle),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          key: ValueKey('b-transport-add-shuttle-${direction.code}'),
          onPressed: () => _addShuttle(direction),
          icon: AppIcon(
            AppIcons.plus,
            size: AppSizes.iconSmall,
            color: context.accentColor,
          ),
          label: Text('${direction.displayName} servisi ekle'),
          style: context.accentOutlinedButtonStyle,
        ),
      ),
    ];
  }

  Widget _shuttleCard(ShuttleDraft shuttle) {
    final index = _draft.shuttles.indexOf(shuttle);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          key: ValueKey('b-transport-shuttle-$index'),
          borderRadius: AppRadius.innerCircular,
          onTap: () => _editShuttle(index),
          child: Padding(
            padding: AppPadding.infoTile,
            child: Row(
              children: [
                AppIcon(
                  AppIcons.bus,
                  size: AppSizes.iconMedium,
                  color: context.accentColor,
                ),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shuttle.name.trim().isEmpty
                            ? 'Servis'
                            : shuttle.name.trim(),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        shuttle.summaryLine,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                      if (shuttle.seatsTaken > 0)
                        Text(
                          '${shuttle.seatsTaken} koltuk seçildi',
                          style: context.textTheme.labelMedium?.copyWith(
                            color: context.accentColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('b-transport-remove-shuttle-$index'),
                  tooltip: 'Servisi sil',
                  onPressed: () => _removeShuttle(index),
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
