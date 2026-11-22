import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/core/directions_links.dart';
import 'package:koala/employee/features/jobs/models/pending_boarding.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// İş detayındaki "Ulaşım" kartı (#197). Yön başına: serviste koltuk seçimi,
/// seçilen servisin plakası/şoförü, durak ve yol tarifi; yol parasında tutar.
///
/// Plaka ve şoför yalnız **seçilen** serviste (sunucu da yalnız orayı
/// gönderiyor). Seçim ve "Değiştir" yalnız [canSelectSeat] iken.
///
/// "Koltuğunuz düştü" iki kaynaktan: sayfanın karşılaştırdığı
/// [droppedDirections] (yön satırında) ve yön söylemeyen `SEAT_DROPPED` push'u
/// ([seatDropped], kartın üstünde). Biniş (#217): koltuğun o kalkıştaki durumu,
/// bekleyen okutma ve [canBoard] iken iki yol.
class WorkTransportCard extends StatelessWidget {
  const WorkTransportCard({
    super.key,
    required this.transport,
    required this.canSelectSeat,
    this.seatDropped = false,
    this.droppedDirections = const {},
    this.busyDirection,
    this.onSelectSeat,
    this.onCall,
    this.onDirections,
    this.canBoard = false,
    this.onScanShuttleQr,
    this.onShowMyQr,
    this.pendingBoardings = const {},
    this.onDismissBoarding,
  });

  final AssignmentTransport transport;

  /// Sunucu aksini `409 TRANSPORT_ASSIGNMENT_NOT_ACTIVE` ile çeviriyor.
  final bool canSelectSeat;

  final bool seatDropped;

  final Set<ShuttleDirection> droppedDirections;

  final ShuttleDirection? busyDirection;

  final void Function(ShuttleDirection direction)? onSelectSeat;

  /// Verilmezse numara düz metin.
  final void Function(String phone)? onCall;

  final void Function(DirectionsTarget target)? onDirections;

  final bool canBoard;

  final void Function(ShuttleDirection direction)? onScanShuttleQr;

  final void Function(ShuttleDirection direction)? onShowMyQr;

  final Map<ShuttleDirection, List<PendingBoarding>> pendingBoardings;

  final void Function(String clientEventId)? onDismissBoarding;

  static const String boardingQueuedText =
      'Biniş okutmanız cihazda saklandı; bağlantı gelince gönderilecek.';

  static const String noShowText =
      'İşvereniniz bu kalkış için "binmedi" işaretledi. Bindiyseniz QR\'ı '
      'yeniden okutun ya da işverene gösterin.';

  static String boardedLine(DateTime occurredAt) =>
      'Bindiniz · ${occurredAt.toLocal().asShortTime}';

  static const double _spinnerStroke = 2;

  static String allowanceLine(double amount) =>
      'İşvereniniz ${formatAllowance(amount)} yol parası verecek.';

  /// Sunucunun `SEAT_DROPPED` bildirimiyle aynı dil.
  static const String seatDroppedText =
      'Seçtiğiniz servis ya da durak plandan kaldırıldı; lütfen yeniden '
      'koltuk seçin.';

  static const String seatDroppedNoticeText =
      'Bir koltuğunuz plandan kaldırıldı; seçimlerinizi kontrol edin.';

  @override
  Widget build(BuildContext context) {
    final notes = transport.notes;

    return Container(
      key: const ValueKey('work-transport-card'),
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
                AppIcons.bus,
                size: AppSizes.iconMedium,
                color: context.accentColor,
              ),
              const SizedBox(width: AppSizes.spaceSmall),
              Text('Ulaşım', style: context.textTheme.titleSmall),
            ],
          ),
          if (seatDropped) ...[
            const SizedBox(height: AppSizes.space),
            _warning(
              context,
              seatDroppedNoticeText,
              key: const ValueKey('work-transport-dropped-notice'),
            ),
          ],
          const SizedBox(height: AppSizes.space),
          _direction(context, ShuttleDirection.outbound),
          const SizedBox(height: AppSizes.space),
          Divider(height: 1, color: context.dividerColor),
          const SizedBox(height: AppSizes.space),
          _direction(context, ShuttleDirection.returnTrip),
          if (notes != null && notes.trim().isNotEmpty) ...[
            const SizedBox(height: AppSizes.space),
            Text(
              'Not: ${notes.trim()}',
              key: const ValueKey('work-transport-notes'),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _direction(BuildContext context, ShuttleDirection direction) {
    final method = transport.methodFor(direction);
    final title = '${direction.displayName} · ${method.displayName}';

    return Column(
      key: ValueKey('work-transport-${direction.code}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        switch (method) {
          TransportMethod.shuttle => _shuttleSection(context, direction),
          TransportMethod.cashAllowance => _allowanceSection(context),
          TransportMethod.self => _line(
            context,
            '${direction.displayName} ulaşımı size ait.',
          ),
          TransportMethod.none => _line(
            context,
            '${direction.displayName} için ulaşım sağlanmıyor.',
          ),
        },
      ],
    );
  }

  Widget _line(BuildContext context, String text) => Text(
    text,
    style: context.textTheme.bodySmall?.copyWith(color: context.textSecondary),
  );

  Widget _allowanceSection(BuildContext context) {
    final amount = transport.allowanceAmount;
    final note = transport.allowanceNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon(
              AppIcons.moneyBag,
              size: AppSizes.iconSmall,
              color: context.accentColor,
            ),
            const SizedBox(width: AppSizes.spaceSmall),
            Expanded(
              child: Text(
                amount == null
                    ? 'İşvereniniz yol parası verecek.'
                    : allowanceLine(amount),
                key: const ValueKey('work-transport-allowance'),
                style: context.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        if (note != null && note.trim().isNotEmpty) ...[
          const SizedBox(height: AppSizes.spaceTiny),
          _line(context, note.trim()),
        ],
      ],
    );
  }

  Widget _shuttleSection(BuildContext context, ShuttleDirection direction) {
    final shuttles = transport.shuttlesFor(direction);
    if (shuttles.isEmpty) {
      return _line(context, 'Bu yön için henüz servis tanımlanmadı.');
    }

    final shuttle = transport.selectedShuttle(direction);
    final stop = transport.selectedStop(direction);
    if (shuttle == null || stop == null) {
      return _unselected(context, direction);
    }

    return _selected(context, direction, shuttle, stop);
  }

  Widget _unselected(BuildContext context, ShuttleDirection direction) {
    // Sayfa karşılaştırdı ya da koltuk kaydı var ama servisi/durağı planda yok.
    final dropped =
        droppedDirections.contains(direction) ||
        transport.seatFor(direction) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dropped) ...[
          _warning(
            context,
            seatDroppedText,
            key: ValueKey('work-transport-dropped-${direction.code}'),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
        ] else
          _line(context, 'Henüz koltuk seçmediniz.'),
        if (canSelectSeat) ...[
          if (!dropped) const SizedBox(height: AppSizes.spaceSmall),
          _seatButton(context, direction, label: 'Koltuk seçin'),
        ],
      ],
    );
  }

  Widget _warning(BuildContext context, String text, {required Key key}) {
    return Container(
      key: key,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            AppIcons.alert,
            size: AppSizes.iconSmall,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(child: Text(text, style: context.textTheme.bodySmall)),
        ],
      ),
    );
  }

  /// Koltuk yokken çerçeveli tam genişlik, seçilmişte yol tarifinin yanında
  /// metin düğmesi.
  Widget _seatButton(
    BuildContext context,
    ShuttleDirection direction, {
    required String label,
    bool outlined = true,
  }) {
    final busy = busyDirection == direction;
    final locked = busyDirection != null || onSelectSeat == null;
    final key = ValueKey('work-transport-select-${direction.code}');
    final onPressed = locked ? null : () => onSelectSeat!(direction);
    final spinner = SizedBox.square(
      dimension: AppSizes.iconSmall,
      child: CircularProgressIndicator(strokeWidth: _spinnerStroke),
    );

    if (!outlined) {
      return TextButton(
        key: key,
        onPressed: onPressed,
        child: busy ? spinner : Text(label),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: AppSizes.actionButtonHeight,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: busy
            ? spinner
            : AppIcon(
                AppIcons.seat,
                size: AppSizes.iconSmall,
                color: context.accentColor,
              ),
        label: Text(label),
        style: context.accentOutlinedButtonStyle,
      ),
    );
  }

  Widget _selected(
    BuildContext context,
    ShuttleDirection direction,
    Shuttle shuttle,
    ShuttleStop stop,
  ) {
    final plate = shuttle.plate;
    final driverName = shuttle.driverName;
    final driverPhone = shuttle.driverPhone;
    final address = stop.addressLine;
    final position = stop.address?.position;
    final target = position == null
        ? null
        : DirectionsTarget(
            latitude: position.latitude,
            longitude: position.longitude,
            arrival: stop.scheduledAt,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shuttle.name,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (plate != null && plate.isNotEmpty)
          _infoRow(
            context,
            AppIcons.bus,
            'Plaka: $plate',
            key: ValueKey('work-transport-plate-${direction.code}'),
          ),
        if (driverName != null && driverName.isNotEmpty)
          _infoRow(context, AppIcons.user, 'Şoför: $driverName'),
        if (driverPhone != null && driverPhone.isNotEmpty)
          _phoneRow(context, driverPhone, direction),
        const SizedBox(height: AppSizes.spaceSmall),
        _infoRow(
          context,
          AppIcons.location,
          address == null || address == stop.displayName
              ? stop.displayName
              : '${stop.displayName} · $address',
          key: ValueKey('work-transport-stop-${direction.code}'),
        ),
        _infoRow(
          context,
          AppIcons.clock,
          'Kalkış: ${stop.scheduledAt.toLocal().asShortDateTime}',
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        Row(
          children: [
            if (target != null && onDirections != null)
              Expanded(
                child: SizedBox(
                  height: AppSizes.actionButtonHeight,
                  child: OutlinedButton.icon(
                    key: ValueKey(
                      'work-transport-directions-${direction.code}',
                    ),
                    onPressed: () => onDirections!(target),
                    icon: AppIcon(
                      AppIcons.route,
                      size: AppSizes.iconSmall,
                      color: context.accentColor,
                    ),
                    label: const Text('Yol tarifi'),
                    style: context.accentOutlinedButtonStyle,
                  ),
                ),
              ),
            if (canSelectSeat) ...[
              if (target != null && onDirections != null)
                const SizedBox(width: AppSizes.spaceSmall),
              _seatButton(
                context,
                direction,
                label: 'Değiştir',
                outlined: false,
              ),
            ],
          ],
        ),
        ..._boardingSection(context, direction),
      ],
    );
  }

  List<Widget> _boardingSection(
    BuildContext context,
    ShuttleDirection direction,
  ) {
    final status = transport.seatFor(direction)?.boarding;
    final entries = pendingBoardings[direction] ?? const <PendingBoarding>[];
    final waiting = entries.any((entry) => !entry.isFailed);
    final boarded = status?.boarded ?? false;
    final showActions =
        canBoard &&
        !boarded &&
        !waiting &&
        (onScanShuttleQr != null || onShowMyQr != null);

    return [
      if (status != null) ...[
        const SizedBox(height: AppSizes.spaceSmall),
        status.boarded
            ? _boardedRow(context, status, direction)
            : _warning(
                context,
                noShowText,
                key: ValueKey('work-transport-no-show-${direction.code}'),
              ),
      ],
      for (final entry in entries) ...[
        const SizedBox(height: AppSizes.spaceSmall),
        entry.isFailed
            ? _failedBoarding(context, entry)
            : _infoNote(
                context,
                boardingQueuedText,
                key: ValueKey(
                  'work-transport-boarding-queued-${direction.code}',
                ),
              ),
      ],
      if (showActions) ...[
        const SizedBox(height: AppSizes.spaceSmall),
        Row(
          children: [
            if (onScanShuttleQr != null)
              Expanded(
                child: _boardingButton(
                  context,
                  key: ValueKey('work-transport-scan-${direction.code}'),
                  icon: AppIcons.scan,
                  label: 'QR okut',
                  onPressed: () => onScanShuttleQr!(direction),
                ),
              ),
            if (onScanShuttleQr != null && onShowMyQr != null)
              const SizedBox(width: AppSizes.spaceSmall),
            if (onShowMyQr != null)
              Expanded(
                child: _boardingButton(
                  context,
                  key: ValueKey('work-transport-my-qr-${direction.code}'),
                  icon: AppIcons.qr,
                  label: 'QR\'ımı göster',
                  onPressed: () => onShowMyQr!(direction),
                ),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _boardingButton(
    BuildContext context, {
    required Key key,
    required AppIconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: AppSizes.actionButtonHeight,
      child: OutlinedButton.icon(
        key: key,
        onPressed: onPressed,
        icon: AppIcon(
          icon,
          size: AppSizes.iconSmall,
          color: context.accentColor,
        ),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: context.accentOutlinedButtonStyle,
      ),
    );
  }

  Widget _boardedRow(
    BuildContext context,
    SeatBoardingStatus status,
    ShuttleDirection direction,
  ) {
    return Row(
      key: ValueKey('work-transport-boarded-${direction.code}'),
      children: [
        const AppIcon(
          AppIcons.checkCircle,
          size: AppSizes.iconSmall,
          color: AppColors.success,
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Expanded(
          child: Text(
            boardedLine(status.occurredAt),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _failedBoarding(BuildContext context, PendingBoarding entry) {
    final failure = entry.failure ?? BoardingFailure.unknown;
    final dismiss = onDismissBoarding;
    return Column(
      key: ValueKey('work-transport-boarding-failed-${entry.clientEventId}'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _warning(
          context,
          failure.message(BoardingActor.worker, queued: true),
          key: ValueKey(
            'work-transport-boarding-failed-text-${entry.clientEventId}',
          ),
        ),
        if (dismiss != null)
          TextButton(
            onPressed: () => dismiss(entry.clientEventId),
            child: const Text('Tamam'),
          ),
      ],
    );
  }

  Widget _infoNote(BuildContext context, String text, {required Key key}) {
    return Container(
      key: key,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.innerCircular,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            AppIcons.info,
            size: AppSizes.iconSmall,
            color: AppColors.info,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(child: Text(text, style: context.textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    AppIconData icon,
    String text, {
    Key? key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(icon, size: AppSizes.iconSmall, color: context.textTertiary),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phoneRow(
    BuildContext context,
    String phone,
    ShuttleDirection direction,
  ) {
    final call = onCall;
    final text = Text(
      phone,
      style: context.textTheme.bodySmall?.copyWith(
        color: call == null ? context.textSecondary : context.accentColor,
        fontWeight: call == null ? null : FontWeight.w600,
        decoration: call == null ? null : TextDecoration.underline,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
      child: Row(
        children: [
          AppIcon(
            AppIcons.call,
            size: AppSizes.iconSmall,
            color: context.textTertiary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          if (call == null)
            text
          else
            InkWell(
              key: ValueKey('work-transport-call-${direction.code}'),
              onTap: () => call(phone),
              child: text,
            ),
        ],
      ),
    );
  }
}
