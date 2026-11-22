part of 'notification_preferences_page.dart';

abstract class NotificationPreferencesPagemodel
    extends State<NotificationPreferencesPage> {
  NotificationPreferenceService get _service =>
      widget.service ?? NotificationPreferenceService();

  List<NotificationPreferenceGroup> groups = const [];
  bool isLoading = true;
  String? errorMessage;

  /// Yazılmakta olan kombinasyonlar; aynı anahtar istek sürerken çevrilemez.
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) setState(() => isLoading = true);

    try {
      final rows = await _service.fetchAll();
      if (!mounted) return;
      setState(() {
        groups = NotificationPreferenceGroup.groupAll(rows);
        errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool isSaving(NotificationPreference row) => _saving.contains(_keyOf(row));

  /// Anahtarı çevirir, sunucunun tablosuyla yeniler. İyimser değil: karar
  /// sunucuda, `400`'de geri dönen anahtar kafa karıştırır.
  Future<void> toggle(NotificationPreference row) async {
    final key = _keyOf(row);
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));

    try {
      final rows = await _service.update([
        NotificationPreferenceWrite(
          category: row.category,
          channel: row.channel,
          enabled: !row.enabled,
        ),
      ]);
      if (!mounted) return;
      setState(() => groups = NotificationPreferenceGroup.groupAll(rows));
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  static String _keyOf(NotificationPreference row) =>
      '${row.category}/${row.channel}';
}
