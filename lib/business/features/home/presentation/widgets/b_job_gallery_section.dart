import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/business/features/home/presentation/widgets/b_gallery_tile.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/product/providers/job_gallery_provider.dart';
import 'package:koala/product/services/gallery_upload_validator.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/job_gallery_view.dart';

typedef GalleryImageChooser = Future<String?> Function();

/// İşveren ilan ayrıntısındaki galeri yönetim yüzeyi.
///
/// Yetkisiz çağrıda aynı galeri salt okunur çizilir. Yönetimde upload,
/// şirket galerisinden medya seçme, sıralama, kapak ve kaldırma tek modülde
/// kalır; bütün mutasyonlar yalnız başarılı `GET` sonrasında açılır.
class BJobGallerySection extends StatefulWidget {
  const BJobGallerySection({
    super.key,
    required this.jobId,
    required this.canManage,
    this.companyImages = const [],
    this.provider,
    this.chooseImage,
  });

  final String jobId;
  final bool canManage;
  final List<GalleryImage> companyImages;

  /// Sayfa yaşam döngüsüne bağlı galeri durumu. Verilmezse modül kendi
  /// provider'ını oluşturur; dışarıdan verilmesi aynı durumu testte veya
  /// üst düzey bir sayfada paylaşmayı sağlar.
  final JobGalleryProvider? provider;

  /// Platform galeri seçicisi. Varsayılanı `image_picker` adapter'ıdır.
  final GalleryImageChooser? chooseImage;

  @override
  State<BJobGallerySection> createState() => _BJobGallerySectionState();
}

class _BJobGallerySectionState extends State<BJobGallerySection> {
  late final JobGalleryProvider _provider;
  late final bool _ownsProvider;
  List<GalleryImage>? _pendingOrder;

  List<GalleryImage> get _images => _pendingOrder ?? _provider.images;

  bool get _canMutate =>
      widget.canManage && _provider.isLoadedFor(widget.jobId);

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.provider == null;
    _provider = widget.provider ?? JobGalleryProvider();
    _provider.addListener(_onChanged);
    _provider.load(widget.jobId);
  }

  @override
  void didUpdateWidget(covariant BJobGallerySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId) {
      _pendingOrder = null;
      _provider.load(widget.jobId);
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_onChanged);
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_canMutate) {
      return JobGalleryView(
        images: _provider.images,
        isLoading: _provider.isLoading,
        errorMessage: _provider.errorMessage,
        onRetry: () => _provider.load(widget.jobId, force: true),
      );
    }

    final isFull = !_provider.canAddImage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('İlan Galerisi', style: context.textTheme.titleSmall),
        const SizedBox(height: AppSizes.spaceSmall),
        Text(
          'Görselleri sürükleyerek sırala; kapak arama kartında öne çıkar.',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Wrap(
          spacing: AppSizes.spaceSmall,
          runSpacing: AppSizes.spaceSmall,
          children: [
            OutlinedButton(
              onPressed: isFull || _provider.isBusy ? null : _pickImage,
              child: const Text('Görsel Yükle'),
            ),
            OutlinedButton(
              onPressed:
                  isFull || _provider.isBusy || _selectableCompanyImages.isEmpty
                  ? null
                  : _selectCompanyImage,
              child: const Text('Şirketten Seç'),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        Text(
          isFull
              ? 'Galeri dolu (${_images.length}/${UploadLimits.maxGalleryImages})'
              : '${_images.length}/${UploadLimits.maxGalleryImages} görsel · '
                    '${UploadLimits.imageRuleLabel}',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
          ),
        ),
        if (_images.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSizes.spaceMedium),
            child: Text(
              'Galeride görsel yok',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
          )
        else ...[
          const SizedBox(height: AppSizes.spaceMedium),
          ReorderableListView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: !_provider.isBusy,
            itemCount: _images.length,
            onReorderItem: _reorder,
            itemBuilder: (context, index) {
              final image = _images[index];
              return BGalleryTile(
                key: ValueKey(image.id),
                image: image,
                position: index + 1,
                canManage: true,
                onSetCover: _provider.isBusy ? null : () => _setCover(image),
                onRemove: _provider.isBusy ? null : () => _remove(image),
              );
            },
          ),
        ],
      ],
    );
  }

  List<GalleryImage> get _selectableCompanyImages {
    final selectedIds = _images.map((image) => image.id).toSet();
    return widget.companyImages
        .where((image) => !selectedIds.contains(image.id))
        .toList();
  }

  Future<void> _pickImage() async {
    final path = await (widget.chooseImage ?? _chooseFromDevice)();
    if (path == null || !mounted) return;

    final error = await GalleryUploadValidator.errorFor(path);
    if (!mounted) return;
    if (error != null) {
      AppToast.error(context, error);
      return;
    }

    await _run(() => _provider.addImage(path), 'Görsel eklendi');
  }

  static Future<String?> _chooseFromDevice() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    return image?.path;
  }

  Future<void> _selectCompanyImage() async {
    final selected = await showModalBottomSheet<GalleryImage>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.spaceMedium),
              child: Text(
                'Şirket Galerisinden Seç',
                style: sheetContext.textTheme.titleMedium,
              ),
            ),
            for (final image in _selectableCompanyImages)
              ListTile(
                leading: Image.network(
                  image.url,
                  width: AppSizes.thumbnail,
                  height: AppSizes.thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox.square(dimension: AppSizes.thumbnail),
                ),
                title: Text(
                  image.caption?.isNotEmpty == true
                      ? image.caption!
                      : 'Şirket görseli',
                ),
                onTap: () => Navigator.of(sheetContext).pop(image),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _run(
      () => _provider.replaceGallery([..._images, selected]),
      'Görsel ilana eklendi',
    );
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final reordered = [..._images];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    setState(() => _pendingOrder = reordered);

    await _run(
      () => _provider.replaceGallery(reordered),
      'Sıralama kaydedildi',
    );
  }

  Future<void> _setCover(GalleryImage image) async {
    final updated = [
      for (final current in _images)
        current.copyWith(isCover: current.id == image.id),
    ];
    await _run(() => _provider.replaceGallery(updated), 'Kapak güncellendi');
  }

  Future<void> _remove(GalleryImage image) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Görseli kaldır',
      message: image.isCover
          ? 'Kapak kaldırılırsa sunucu sıradaki görseli kapak yapar.'
          : 'Görsel bu ilanın galerisinden kaldırılacak.',
      actionLabel: 'Kaldır',
    );
    if (confirmed != true || !mounted) return;

    await _run(() => _provider.removeImage(image.id), 'Görsel kaldırıldı');
  }

  Future<void> _run(Future<bool> Function() action, String success) async {
    final succeeded = await action();
    if (!mounted) return;
    setState(() => _pendingOrder = null);

    if (succeeded) {
      AppToast.success(context, success);
    } else {
      AppToast.error(context, _provider.errorMessage ?? 'İşlem tamamlanamadı');
    }
  }
}
