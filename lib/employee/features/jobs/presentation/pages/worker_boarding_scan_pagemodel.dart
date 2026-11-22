part of 'worker_boarding_scan_page.dart';

abstract class WorkerBoardingScanPagemodel
    extends State<WorkerBoardingScanPage> {
  bool busy = false;

  BoardingResultPanel? lastResult;

  BoardingResultPanel? finishedResult;

  WorkerBoardingSubmitter _submitter() =>
      widget.submitter ??
      WorkerBoardingSubmitter(
        queue: context.read<BoardingQueueProvider>(),
        users: context.read<UserProvider>(),
      );

  Future<void> onToken(BoardingToken token, DateTime capturedAt) async {
    if (busy || finishedResult != null) return;

    final expected = widget.expectedShuttleId?.toLowerCase();
    if (expected != null && expected != token.subjectId) {
      setState(
        () => lastResult = BoardingResultPanel(
          tone: BoardingResultTone.failure,
          message: BoardingFailure.wrongShuttle.message(BoardingActor.worker),
        ),
      );
      return;
    }

    setState(() {
      busy = true;
      lastResult = null;
    });
    try {
      final submission = await _submitter().submit(
        token: token,
        capturedAt: capturedAt,
        assignmentId: widget.assignmentId,
        direction: widget.direction,
      );
      if (!mounted) return;
      setState(() => _apply(submission));
    } catch (_) {
      // Hata metni token taşıyabilir; yazdırılmıyor.
      if (!mounted) return;
      setState(
        () => lastResult = const BoardingResultPanel(
          tone: BoardingResultTone.failure,
          message: 'Biniş kaydedilemedi; yeniden deneyin.',
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _apply(BoardingSubmission submission) {
    final panel = WorkerBoardingScanPage.resultFor(submission);
    if (submission is BoardingRejected) {
      lastResult = panel;
    } else {
      finishedResult = panel;
    }
  }
}
