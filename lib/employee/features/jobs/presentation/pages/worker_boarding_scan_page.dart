import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/employee/features/jobs/services/worker_boarding_submitter.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/boarding_failure.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_result_panel.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_scanner.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:provider/provider.dart';

part 'worker_boarding_scan_pagemodel.dart';

/// İşçi servisteki QR'ı okutur (#217). Okutma kuyruğa gider (çevrimdışıyken
/// saklanır); kayıtta kamera kapanır, retde açık kalır.
class WorkerBoardingScanPage extends StatefulWidget {
  const WorkerBoardingScanPage({
    super.key,
    this.assignmentId,
    this.direction,
    this.expectedShuttleId,
    this.submitter,
    this.cameraBuilder,
    this.permissionProbe,
    this.appScheme,
  });

  final String? assignmentId;
  final ShuttleDirection? direction;

  /// Biliniyorsa yanlış servis çevrimdışıyken de hemen söylenir; son söz
  /// sunucunun.
  final String? expectedShuttleId;

  final WorkerBoardingSubmitter? submitter;
  final BoardingCameraBuilder? cameraBuilder;
  final CameraPermissionProbe? permissionProbe;
  final String? appScheme;

  static const String instruction =
      'Bindiğiniz servisteki QR kodunu çerçevenin içine getirin.';

  static const String unavailableHint =
      'Bunun yerine iş detayındaki "QR\'ımı göster" ile kendi QR\'ınızı '
      'işverene okutabilirsiniz.';

  static BoardingResultPanel resultFor(BoardingSubmission submission) {
    return switch (submission) {
      BoardingRecorded(:final event) => BoardingResultPanel(
        tone: BoardingResultTone.success,
        message: 'Binişiniz kaydedildi.',
        detail: event.replayed
            ? 'Bu kalkış için binişiniz zaten kayıtlıydı.'
            : null,
      ),
      BoardingQueued() => const BoardingResultPanel(
        tone: BoardingResultTone.queued,
        message: 'İnternet bağlantısı yok; okutmanız cihazda saklandı.',
        detail: 'Bağlantı gelince otomatik gönderilecek.',
      ),
      BoardingRejected(:final failure, :final serverMessage) =>
        BoardingResultPanel(
          tone: BoardingResultTone.failure,
          message: failure.message(
            BoardingActor.worker,
            serverMessage: serverMessage,
          ),
        ),
    };
  }

  /// `/boarding-link` işçi oturumunda buradan gönderilir.
  static Future<BoardingResultPanel> submitFromLink(
    BuildContext context,
    BoardingToken token,
    DateTime capturedAt,
  ) async {
    final submitter = WorkerBoardingSubmitter(
      queue: context.read<BoardingQueueProvider>(),
      users: context.read<UserProvider>(),
    );
    try {
      return resultFor(
        await submitter.submit(token: token, capturedAt: capturedAt),
      );
    } catch (_) {
      return const BoardingResultPanel(
        tone: BoardingResultTone.failure,
        message: 'Biniş kaydedilemedi; yeniden deneyin.',
      );
    }
  }

  @override
  State<WorkerBoardingScanPage> createState() => _WorkerBoardingScanPageState();
}

class _WorkerBoardingScanPageState extends WorkerBoardingScanPagemodel {
  @override
  Widget build(BuildContext context) {
    final finished = finishedResult;

    return Scaffold(
      appBar: const MyAppbar(title: 'Servis QR\'ını okut'),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: finished != null
              ? _finished(context, finished)
              : BoardingScannerView(
                  actor: BoardingActor.worker,
                  acceptedKind: BoardingTokenKind.shuttle,
                  instruction: WorkerBoardingScanPage.instruction,
                  unavailableHint: WorkerBoardingScanPage.unavailableHint,
                  busy: busy,
                  status: lastResult,
                  onToken: onToken,
                  cameraBuilder: widget.cameraBuilder,
                  permissionProbe: widget.permissionProbe,
                  appScheme: widget.appScheme,
                ),
        ),
      ),
    );
  }

  Widget _finished(BuildContext context, BoardingResultPanel result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        result,
        const Spacer(),
        Text(
          'Biniş durumunuz iş detayındaki Ulaşım kartında görünür.',
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.space),
        MyButton(
          key: const ValueKey('worker-boarding-scan-done'),
          title: 'Tamam',
          onPressed: () => context.pop(true),
        ),
      ],
    );
  }
}
