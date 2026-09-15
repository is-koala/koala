part of 'b_shuttle_editor_page.dart';

abstract class BShuttleEditorPagemodel extends State<BShuttleEditorPage> {
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
}
