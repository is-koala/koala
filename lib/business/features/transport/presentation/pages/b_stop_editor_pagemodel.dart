part of 'b_stop_editor_page.dart';

abstract class BStopEditorPagemodel extends State<BStopEditorPage> {
  static const Duration _defaultLeadBeforeJob = Duration(hours: 1);

  late final StopDraft _stop = widget.args.stop.copy();
  late final _labelController = TextEditingController(text: _stop.label);

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final jobStart = widget.args.jobStart;
    final picked = await DateTimePicking.pick(
      context,
      initial: _stop.scheduledAt ?? jobStart?.subtract(_defaultLeadBeforeJob),
    );
    if (picked == null || !mounted) return;
    setState(() => _stop.scheduledAt = picked);
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
      // Doğrulama metni küçük harfle başlıyor; burada tek başına yazılıyor.
      AppToast.error(context, _capitalize(error));
      return;
    }
    context.pop(_stop);
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
