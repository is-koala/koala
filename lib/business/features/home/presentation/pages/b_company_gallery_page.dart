import 'package:material_ui/material_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/widgets/b_gallery_tile.dart';
import 'package:koala/business/features/home/services/b_gallery_upload_validator.dart';
import 'package:koala/product/models/gallery_image.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/constants/upload_limits.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'b_company_gallery_pagemodel.dart';

/// Şirket galerisi yönetimi. Uçlar galerinin tamamını döndürüyor, ekran listeyi
/// hesaplamıyor. Sıralama bırakıldığı anda **galerinin tamamı** tek `PUT` ile
/// gider. Denetimler yalnız `ADMIN`'de: sunucu yetkisize `404` döndürdüğü için
/// düğme yanıltıcı hataya çıkardı.
class BCompanyGalleryPage extends StatefulWidget {
  const BCompanyGalleryPage({super.key});

  @override
  State<BCompanyGalleryPage> createState() => _BCompanyGalleryPageState();
}

class _BCompanyGalleryPageState extends BCompanyGalleryPagemodel {
  static const double _spinnerStroke = 2;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BCompanyProvider>();

    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: 'Şirket Galerisi'),
      body: _body(provider),
    );
  }

  Widget _body(BCompanyProvider provider) {
    if (provider.isLoading && provider.company == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = provider.errorMessage;
    if (message != null && provider.company == null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Galeri alınamadı',
        description: message,
        action: OutlinedButton(
          onPressed: reload,
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    if (provider.company == null) {
      return const EmptyState(
        icon: AppIcons.building,
        title: 'Kayıtlı firmanız yok',
        description:
            'Galeri şirkete ait; bireysel işveren olarak ilan '
            'yayınlıyorsunuz.',
      );
    }

    return ReorderableListView.builder(
      padding: AppPadding.primaryAll,
      header: _header(provider),
      // Sürükleme yalnız yetkilide ve istek uçmuyorken; yoksa ikinci `PUT`
      // yanıttan önce giderdi.
      buildDefaultDragHandles: canManage && !provider.isGalleryBusy,
      onReorderItem: onReorder,
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];

        return BGalleryTile(
          key: ValueKey(image.id),
          image: image,
          position: index + 1,
          canManage: canManage,
          onSetCover: provider.isGalleryBusy ? null : () => setCover(image),
          onRemove: provider.isGalleryBusy ? null : () => remove(image),
        );
      },
    );
  }

  Widget _header(BCompanyProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _intro(),
        const SizedBox(height: AppSizes.spaceMedium),
        if (canManage) ...[_addButton(provider), _limitNotice(provider)],
        if (images.isEmpty) _emptyGallery(),
        const SizedBox(height: AppSizes.space),
      ],
    );
  }

  Widget _intro() {
    return Text(
      canManage
          ? 'İş yerinizin fotoğrafları ilan sayfanızda görünür. Sıralamak '
                'için bir görsele basılı tutup sürükleyin; ilk sıradaki '
                'görsel kapak olmak zorunda değil, kapağı siz seçersiniz.'
          : 'İş yerinizin fotoğrafları ilan sayfanızda görünür. Galeriyi '
                'yalnızca şirketin yöneticisi düzenleyebilir.',
      style: context.textTheme.bodySmall?.copyWith(
        color: context.textSecondary,
        height: 1.5,
      ),
    );
  }

  Widget _addButton(BCompanyProvider provider) {
    final canAdd = provider.canAddGalleryImage && !provider.isGalleryBusy;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: canAdd ? pickImage : null,
        icon: provider.isGalleryBusy
            ? SizedBox.square(
                dimension: AppSizes.iconSmall,
                child: CircularProgressIndicator(
                  strokeWidth: _spinnerStroke,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.accentColor,
                  ),
                ),
              )
            : const AppIcon(AppIcons.plus, size: AppSizes.iconSmall),
        label: const Text('Görsel Ekle'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.accentColor,
          side: BorderSide(color: context.accentColor),
          textStyle: context.textTheme.labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.innerCircular,
          ),
        ),
      ),
    );
  }

  Widget _limitNotice(BCompanyProvider provider) {
    final isFull = !provider.canAddGalleryImage;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceSmall),
      child: Text(
        isFull
            ? 'Galeri dolu (${images.length}/${UploadLimits.maxGalleryImages}). '
                  'Yeni görsel eklemek için önce birini kaldırın.'
            : '${images.length}/${UploadLimits.maxGalleryImages} görsel · '
                  '${UploadLimits.imageRuleLabel}',
        style: context.textTheme.bodySmall?.copyWith(
          color: context.textTertiary,
        ),
      ),
    );
  }

  Widget _emptyGallery() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.sectionSpace),
      child: Column(
        children: [
          AppIcon(
            AppIcons.gallery,
            size: AppSizes.iconHuge,
            color: context.dividerColor,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            'Galeride görsel yok',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
