part of 'b_job_templates_page.dart';

abstract class BJobTemplatesPagemodel extends State<BJobTemplatesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BJobTemplatesProvider>().load();
    });
  }

  /// Kart özeti: kategori, pozisyon ve iş tipi.
  ///
  /// Şablonun adı kullanıcının verdiği ad, ilan başlığı ayrı; ikisi
  /// birbirinden farklı olabildiği için başlık da özete giriyor.
  String _summary(JobTemplate template) {
    final values = <String>[
      if (template.category != null) template.category!.displayName,
      if (template.position != null && template.position!.isNotEmpty)
        template.position!,
      if (template.title != null && template.title!.isNotEmpty) template.title!,
      template.type.displayName,
    ];
    return values.join(' · ');
  }

  /// Şablonu siler.
  ///
  /// Silme geri alınamıyor ve sunucuda düzenleme ucu yok, o yüzden önce onay
  /// isteniyor. Kaldırma iyimser: sunucu reddederse satır geri geliyor.
  Future<void> _delete(
    BuildContext context,
    BJobTemplatesProvider provider,
    JobTemplate template,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Şablonu Sil',
      message:
          '"${template.templateName}" şablonu silinsin mi? '
          'Bu işlem geri alınamaz.',
      actionLabel: 'Sil',
    );
    if (confirmed != true || !context.mounted) return;

    final removed = await provider.delete(template.id);
    if (!removed && context.mounted) {
      AppToast.error(context, provider.errorMessage ?? 'Şablon silinemedi.');
    }
  }
}
