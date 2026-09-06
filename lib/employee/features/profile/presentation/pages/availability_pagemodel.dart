part of 'availability_page.dart';

abstract class AvailabilityPageModel extends State<AvailabilityPage> {
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

  Future<void> _addSlot(String dayOfWeek) async {
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
    if (end == null || !mounted) return;

    final slot = AvailabilitySlot(
      dayOfWeek: dayOfWeek,
      startTime: _asApiTime(start),
      endTime: _asApiTime(end),
    );
    if (slot.startMinutes >= slot.endMinutes) {
      AppToast.error(context, 'Bitiş saati başlangıç saatinden sonra olmalı.');
      return;
    }

    final provider = context.read<AvailabilityProvider>();
    provider.replaceDaySlots(dayOfWeek, [
      ...provider.slotsForDay(dayOfWeek),
      slot,
    ]);
  }

  void _removeSlot(String dayOfWeek, int index) {
    final provider = context.read<AvailabilityProvider>();
    final slots = provider.slotsForDay(dayOfWeek);
    if (index < 0 || index >= slots.length) return;
    provider.replaceDaySlots(dayOfWeek, [...slots]..removeAt(index));
  }

  Future<void> _saveWeekly() async {
    final provider = context.read<AvailabilityProvider>();
    final saved = await provider.saveWeekly();
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
    final input = await AvailabilityExceptionSheet.show(
      context,
      initial: initial,
    );
    if (input == null || !mounted) return;

    final provider = context.read<AvailabilityProvider>();
    final saved = await provider.saveException(
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Tarih istisnasını sil',
      message: '${exception.date.asShortDate} tarihli kayıt silinecek.',
      actionLabel: 'Sil',
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<AvailabilityProvider>();
    final deleted = await provider.deleteException(exception.id);
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
