import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/models/identity_declaration.dart';
import 'package:koala/product/models/upload_progress.dart';
import 'package:koala/employee/features/settings/models/identity_document_error.dart';
import 'package:koala/employee/features/settings/models/identity_photo.dart';
import 'package:koala/employee/features/settings/models/identity_photo_slot.dart';
import 'package:koala/employee/features/settings/models/identity_review.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_declaration_fields.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_photo_source_sheet.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_photo_tile.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_review_status_view.dart';
import 'package:koala/employee/features/settings/services/identity_document_service.dart';
import 'package:koala/employee/features/settings/services/identity_photo_picker.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:provider/provider.dart';

part 'identity_documents_pagemodel.dart';

/// Fotoğraflı kimlik doğrulama: beş alanlık beyan, dört kare, tek istek.
///
/// Ürünün ana yolu (devir belgesi §4): kimlik kartının ön ve arka yüzü,
/// yüz ve kimlikle yüz aynı karede; personel inceleyip onaylıyor, kimlik
/// **onaydan sonra** damgalanıyor. Çip yolu bunun yanında duruyor, yerine
/// geçmiyor.
///
/// Ekran açılırken son incelemeyi okuyor ve ona göre çiziliyor:
///
/// - inceleme yok → form,
/// - `REJECTED` → gerekçe + aynı form (yeniden yükleme),
/// - `PENDING` → bekleme görünümü; sunucu ikinci yüklemeyi zaten reddediyor,
/// - `APPROVED` → onay görünümü, `/users/me` tazelenip `true` ile kapanıyor.
///
/// Gönderim `true` ile **kapanmıyor**: inceleme açıldı ama kimlik henüz
/// doğrulanmadı. Çağıran kapılar (`CompanyIdentityGate`, başvuru hazırlığı)
/// `true`'yu "doğrulandı" sayıyor; bekleyen bir incelemeyi öyle göstermek
/// onları sunucunun az sonra reddedeceği bir yola sokardı.
class IdentityDocumentsPage extends StatefulWidget {
  const IdentityDocumentsPage({
    super.key,
    required this.user,
    this.service,
    this.picker,
  });

  final CurrentUser user;

  /// Testlerde sahte sunucuya bağlı servis.
  final IdentityDocumentService? service;

  /// Testlerde kamera ve galeri olmadan dosya veren seçici.
  final IdentityPhotoPicker? picker;

  @override
  State<IdentityDocumentsPage> createState() => _IdentityDocumentsPageState();
}

class _IdentityDocumentsPageState extends IdentityDocumentsPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Fotoğrafla Doğrulama'),
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    return switch (stage) {
      IdentityDocumentsStage.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      IdentityDocumentsStage.loadFailed => _loadFailed(),
      IdentityDocumentsStage.form ||
      IdentityDocumentsStage.uploading => _form(),
      IdentityDocumentsStage.pending => IdentityReviewStatusView.pending(
        review: review,
        onRefresh: isRefreshing ? null : refreshStatus,
        onLeave: leave,
        isRefreshing: isRefreshing,
      ),
      IdentityDocumentsStage.approved => IdentityReviewStatusView.approved(
        onLeave: leaveVerified,
      ),
    };
  }

  Widget? _bottomBar() {
    return switch (stage) {
      IdentityDocumentsStage.form => ButtonNavbar(
        onPressed: canSubmit ? submit : null,
        title: 'İncelemeye Gönder',
      ),
      IdentityDocumentsStage.uploading => ButtonNavbar(
        onPressed: null,
        title: 'Gönderiliyor',
        isLoading: true,
      ),
      _ => null,
    };
  }

  // ------------------------------------------------------------------ Form

  Widget _form() {
    final rejected = review;
    final photoCount = photos.length;

    return FormPageBody(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rejected != null && rejected.isRejected) ...[
            IdentityRejectionNotice(review: rejected),
            const SizedBox(height: AppSizes.spaceMedium),
          ],
          _intro(),
          if (failure != null) ...[
            const SizedBox(height: AppSizes.spaceMedium),
            _failureNotice(failure!),
          ],
          const SizedBox(height: AppSizes.spaceLarge),
          _sectionTitle('Kimlik bilgilerin'),
          const SizedBox(height: AppSizes.space),
          IdentityDeclarationFields(
            firstName: firstName,
            lastName: lastName,
            tcIdentity: tcIdentity,
            tcDocument: tcDocument,
            birthDate: birthDate,
            onChanged: () => setState(() {}),
            onBirthDateChanged: (picked) => setState(() => birthDate = picked),
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          _sectionTitle(
            'Fotoğraflar ($photoCount/${IdentityPhotoSlot.values.length})',
          ),
          const SizedBox(height: AppSizes.space),
          for (final (index, slot) in IdentityPhotoSlot.values.indexed) ...[
            IdentityPhotoTile(
              key: ValueKey('identity-photo-${slot.name}'),
              order: index + 1,
              slot: slot,
              photo: photos[slot],
              onPick: () => pick(slot),
              onRemove: () => remove(slot),
              enabled: stage == IdentityDocumentsStage.form,
            ),
            const SizedBox(height: AppSizes.space),
          ],
          if (stage == IdentityDocumentsStage.uploading) ...[
            const SizedBox(height: AppSizes.spaceSmall),
            _progress(),
          ],
          const SizedBox(height: AppSizes.navBarClearance),
        ],
      ),
    );
  }

  Widget _intro() {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(
        'Kimliğini dört fotoğrafla doğruluyoruz: kartın ön ve arka yüzü, '
        'yüzün ve kimlikle birlikte yüzün. Personel inceledikten sonra '
        'kimliğin doğrulanır; bilgiler kimlik kartındakiyle birebir aynı '
        'olmalı. Fotoğraflar tek seferde gönderilir; PNG veya JPG, '
        'her biri en fazla 10 MB.',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.textSecondary,
          height: _lineHeight,
        ),
      ),
    );
  }

  /// Bilgilendirme metinlerinin satır aralığı; kimlik ekranlarındakiyle aynı.
  static const double _lineHeight = 1.4;

  /// Uyarı zemininin saydamlığı; form kırmızıya boyanmasın.
  static const double _failureSurfaceAlpha = 0.1;

  Widget _sectionTitle(String title) => Text(
    title,
    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );

  /// Son gönderimin neden reddedildiği; bir sonraki denemeye kadar duruyor.
  /// Toast yerine sabit bir kutu: dört dosyalık bir yüklemenin sonucu birkaç
  /// saniyede kaybolmamalı.
  Widget _failureNotice(IdentityDocumentsFailure failure) {
    return Container(
      width: double.infinity,
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: _failureSurfaceAlpha),
        borderRadius: AppRadius.innerCircular,
        border: Border.all(color: AppColors.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppIcon(
            AppIcons.alert,
            size: AppSizes.iconMedium,
            color: AppColors.danger,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(failure.message, style: context.textTheme.bodyMedium),
                if (failure.showSupport) ...[
                  const SizedBox(height: AppSizes.spaceTiny),
                  Text(
                    'Destek: ${AppInfo.supportEmail}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress() {
    final value = progress;
    final percent = value == null ? null : (value * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppRadius.stadiumCircular,
          child: LinearProgressIndicator(value: value),
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        Text(
          percent == null
              ? 'Fotoğraflar gönderiliyor…'
              : 'Fotoğraflar gönderiliyor… %$percent',
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- Yüklenemedi

  Widget _loadFailed() {
    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppIcon(
            AppIcons.alert,
            size: AppSizes.iconLarge,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            'İnceleme durumu alınamadı',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            loadError ?? 'Sunucuya ulaşılamadı.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          MyButton(onPressed: load, title: 'Tekrar Dene'),
        ],
      ),
    );
  }
}
