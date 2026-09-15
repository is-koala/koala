part of 'b_transport_plan_page.dart';

abstract class BTransportPlanPagemodel extends State<BTransportPlanPage> {
  TransportService get _service => widget.service ?? TransportService();

  String? get _jobId => widget.args.jobId;

  /// Üzerinde çalışılan taslak. Açılış değeri kopyalanıyor ki geri çıkınca
  /// çağıranın elindeki taslak değişmemiş olsun.
  late TransportPlanDraft _draft = _copyOf(
    widget.args.initial ?? TransportPlanDraft(),
  );

  /// İlan modunda sunucudaki plan; silme uyarısı koltukları buradan sayıyor.
  late TransportPlan? _original = widget.args.original;

  /// İlan modunda plan okunurken; taslak modunda hiç açılmıyor.
  bool _isLoading = false;
  String? _loadError;
  bool _isSaving = false;

  late final _allowanceController = TextEditingController(
    text: _allowanceText(_draft.allowanceAmount),
  );
  late final _allowanceNoteController = TextEditingController(
    text: _draft.allowanceNote,
  );
  late final _notesController = TextEditingController(text: _draft.notes);

  @override
  void initState() {
    super.initState();
    // İlan modunda açılış planı verilmediyse sunucudan okunuyor.
    if (_jobId != null && widget.args.initial == null) {
      unawaited(_loadPlan());
    }
  }

  @override
  void dispose() {
    _allowanceController.dispose();
    _allowanceNoteController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  static TransportPlanDraft _copyOf(TransportPlanDraft source) =>
      TransportPlanDraft(
        outboundMethod: source.outboundMethod,
        returnMethod: source.returnMethod,
        allowanceAmount: source.allowanceAmount,
        allowanceNote: source.allowanceNote,
        notes: source.notes,
        shuttles: [for (final shuttle in source.shuttles) shuttle.copy()],
      );

  static String _allowanceText(double? amount) {
    if (amount == null) return '';
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return '$amount';
  }

  /// `GET /jobs/{id}/transport-plan`; `404 TRANSPORT_PLAN_NOT_FOUND` "henüz
  /// plan yok" demek ve boş taslak açılıyor. Başka hata şerit çiziyor —
  /// kaydetmek mevcut planın üstüne yazacağı için kullanıcı bilmeli.
  Future<void> _loadPlan() async {
    final jobId = _jobId;
    if (jobId == null) return;

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final plan = await _service.fetchPlan(jobId);
      if (!mounted) return;
      setState(() {
        _original = plan;
        _draft = TransportPlanDraft.fromPlan(plan);
        _allowanceController.text = _allowanceText(_draft.allowanceAmount);
        _allowanceNoteController.text = _draft.allowanceNote;
        _notesController.text = _draft.notes;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      final noPlan =
          error.type == ApiErrorType.notFound &&
          (error.errorCode == null ||
              error.errorCode == TransportErrorCodes.planNotFound);
      if (!noPlan) setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMethod(ShuttleDirection direction) async {
    final picked = await OptionSheet.show<TransportMethod>(
      context,
      title: '${direction.displayName} yöntemi',
      options: TransportMethod.values,
      selected: _draft.methodFor(direction),
      labelOf: (method) => method.displayName,
    );
    if (picked == null || !mounted) return;
    setState(() => _draft.setMethod(direction, picked));
  }

  Future<void> _addShuttle(ShuttleDirection direction) =>
      _openShuttleEditor(ShuttleDraft(direction: direction), null);

  Future<void> _editShuttle(int index) =>
      _openShuttleEditor(_draft.shuttles[index], index);

  Future<void> _openShuttleEditor(ShuttleDraft shuttle, int? index) async {
    final saved = await context.push<ShuttleDraft>(
      BusinessRoutes.transportShuttle,
      extra: BShuttleEditorArgs(
        shuttle: shuttle,
        jobStart: widget.args.jobStart,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      if (index == null) {
        _draft.shuttles.add(saved);
      } else {
        _draft.shuttles[index] = saved;
      }
    });
  }

  /// Koltuğu olan servisi silmek onay istiyor ("N çalışanın koltuğu
  /// düşecek"); sayı sunucunun `seatsTaken` alanından.
  Future<void> _removeShuttle(int index) async {
    final shuttle = _draft.shuttles[index];
    final seats = shuttle.droppedSeatsIfRemoved;
    if (seats > 0) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Servisi sil',
        message:
            '$seats çalışanın koltuğu düşecek; plan kaydedilince yeniden '
            'koltuk seçmeleri istenecek.',
        actionLabel: 'Sil',
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _draft.shuttles.removeAt(index));
  }

  /// Alanları taslağa yazar.
  void _syncFields() {
    final amountText = _allowanceController.text.trim().replaceAll(',', '.');
    _draft
      ..allowanceAmount = amountText.isEmpty
          ? null
          : double.tryParse(amountText)
      ..allowanceNote = _allowanceNoteController.text
      ..notes = _notesController.text;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    _syncFields();

    final error = _draft.validate();
    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    final jobId = _jobId;
    if (jobId == null) {
      context.pop(_draft);
      return;
    }

    // Sunucudaki plana göre düşecek koltuklar: silinen servis/durak.
    final dropped = _draft.droppedSeats(_original);
    if (dropped > 0) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Koltuklar düşecek',
        message:
            '$dropped çalışanın koltuğu düşecek ve yeniden seçmeleri '
            'istenecek. Planı kaydetmek istiyor musunuz?',
        actionLabel: 'Kaydet',
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isSaving = true);
    try {
      final saved = await _service.savePlan(jobId, _draft.toWrite());
      if (!mounted) return;
      AppToast.success(context, 'Ulaşım planı kaydedildi.');
      context.pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, _messageFor(error));
      // Elimizdeki servis/durak kimliği sunucuda artık yok: plan yeniden
      // okunmalı, yoksa her deneme aynı 404'e çarpar.
      if (TransportErrorCodes.staleReferences.contains(error.errorCode)) {
        await _loadPlan();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Sunucu mesajı Türkçe ve yeterli; alan hatasında (`400`) ilk alanın
  /// mesajı, kalan `409`larda doğrudan mesaj.
  static String _messageFor(ApiException error) {
    final field = error.fieldErrors.firstOrNull;
    if (field != null && field.message.isNotEmpty) return field.message;
    return error.message;
  }
}
