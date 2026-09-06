part of 'availability_page.dart';

abstract class AvailabilityPagemodel extends State<AvailabilityPage> {
  static const TimeOfDay _defaultStartTime = TimeOfDay(hour: 9, minute: 0);
  static const TimeOfDay _defaultEndTime = TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _ensureLoaded() async {
    final userProvider = context.read<UserProvider>();
    if (userProvider.user == null) await userProvider.load();
    if (!mounted) return;

    final user = userProvider.user;
    if (user == null) {
      AppToast.error(
        context,
        userProvider.errorMessage ?? 'Profil bilgisi alınamadı.',
      );
      return;
    }

    final provider = context.read<AvailabilityProvider>();
    if (!provider.isLoadedFor(user.id)) await provider.load(user.id);
  }

  Future<void> _reload() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      await _ensureLoaded();
      return;
    }
    await context.read<AvailabilityProvider>().load(user.id, silent: true);
  }

  String? get _editableUserId {
    final userId = context.read<UserProvider>().user?.id;
    if (userId == null) return null;
    return context.read<AvailabilityProvider>().isLoadedFor(userId)
        ? userId
        : null;
  }

  Future<void> _addSlot(AvailabilityDay day) async {
    final userId = _editableUserId;
    if (userId == null) return;

    final start = await showTimePicker(
      context: context,
      initialTime: _defaultStartTime,
      helpText: 'Başlangıç saatini seç',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: _defaultEndTime,
      helpText: 'Bitiş saatini seç',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (end == null || !mounted || _editableUserId != userId) return;

    final slot = AvailabilitySlot(
      day: day,
      startTime: _asApiTime(start),
      endTime: _asApiTime(end),
    );
    if (slot.startMinutes >= slot.endMinutes) {
      AppToast.error(context, 'Bitiş saati başlangıç saatinden sonra olmalı.');
      return;
    }

    final provider = context.read<AvailabilityProvider>();
    provider.replaceDaySlots(userId, day, [...provider.slotsForDay(day), slot]);
  }

  void _removeSlot(AvailabilityDay day, int index) {
    final userId = _editableUserId;
    if (userId == null) return;

    final provider = context.read<AvailabilityProvider>();
    final slots = provider.slotsForDay(day);
    if (index < 0 || index >= slots.length) return;
    provider.replaceDaySlots(userId, day, [...slots]..removeAt(index));
  }

  Future<void> _saveWeekly() async {
    final userId = _editableUserId;
    if (userId == null) return;

    final provider = context.read<AvailabilityProvider>();
    final saved = await provider.saveWeekly(userId);
    if (!mounted) return;

    if (saved) {
      AppToast.success(context, 'Haftalık müsaitliğin kaydedildi.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Müsaitlik kaydedilemedi.',
      );
    }
  }

  Future<void> _editException([AvailabilityException? initial]) async {
    final userId = _editableUserId;
    if (userId == null) return;

    final input = await AvailabilityExceptionSheet.show(
      context,
      initial: initial,
    );
    if (input == null || !mounted || _editableUserId != userId) return;

    final provider = context.read<AvailabilityProvider>();
    final saved = await provider.saveException(
      userId: userId,
      date: input.date,
      available: input.available,
      note: input.note,
    );
    if (!mounted) return;

    if (saved) {
      AppToast.success(context, 'Tarih istisnası kaydedildi.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Tarih istisnası kaydedilemedi.',
      );
    }
  }

  Future<void> _deleteException(AvailabilityException exception) async {
    final userId = _editableUserId;
    final exceptionId = exception.id;
    if (userId == null || exceptionId == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Tarih istisnasını sil',
      message: '${exception.date.asShortDate} tarihli kayıt silinecek.',
      actionLabel: 'Sil',
    );
    if (confirmed != true || !mounted || _editableUserId != userId) return;

    final provider = context.read<AvailabilityProvider>();
    final deleted = await provider.deleteException(userId, exceptionId);
    if (!mounted) return;

    if (deleted) {
      AppToast.success(context, 'Tarih istisnası silindi.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Tarih istisnası silinemedi.',
      );
    }
  }

  String _asApiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
