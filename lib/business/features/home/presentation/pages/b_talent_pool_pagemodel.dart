part of 'b_talent_pool_page.dart';

abstract class BTalentPoolPagemodel extends State<BTalentPoolPage> {
  /// Satırdaki avatar; başvuran kartıyla aynı ölçek.
  static const double _avatarSize = 48;

  final ScrollController _scrollController = ScrollController();

  /// Listenin sonuna bu kadar kala sonraki sayfa isteniyor.
  static const double _loadMoreThreshold = 240;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BTalentPoolProvider>().load();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final remaining =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    if (remaining <= _loadMoreThreshold) {
      context.read<BTalentPoolProvider>().loadMore();
    }
  }

  Future<void> _editNote(
    BuildContext context,
    BTalentPoolProvider provider,
    TalentPoolEntry entry,
  ) async {
    final note = await ReasonDialog.show(
      context,
      title: 'Notu güncelle',
      description: '${entry.worker.fullName} için havuz notu.',
      fieldLabel: 'Not',
      confirmLabel: 'Kaydet',
      isDestructive: false,
      initialText: entry.note,
      maxLength: TalentPoolService.maxNoteLength,
    );
    if (note == null || !context.mounted) return;

    final updated = await provider.addWorker(entry.worker, note: note);
    if (!updated && context.mounted) {
      AppToast.error(context, provider.errorMessage ?? 'Not güncellenemedi.');
    }
  }

  Future<void> _remove(
    BuildContext context,
    BTalentPoolProvider provider,
    TalentPoolEntry entry,
  ) async {
    final removed = await provider.removeWorker(entry.worker.id);
    if (!removed && context.mounted) {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Havuzdan çıkarılamadı.',
      );
    }
  }
}
