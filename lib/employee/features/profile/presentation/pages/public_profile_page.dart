import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_reviews.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/profile_cover.dart';
import 'package:provider/provider.dart';

part 'public_profile_pagemodel.dart';

/// Çalışanın başka bir kullanıcının herkese açık profilini gördüğü sayfa
/// (is-koala/koala#182): grup sohbetinin katılımcısı ya da bireysel ilanın
/// işvereni.
///
/// İki kez çiziliyor: [PublicProfileArgs] çağıranın bildiği ad, fotoğraf ve
/// rolle kapağı hemen çiziyor; `GET /users/{id}` gelince meslek, konum ve
/// hakkında doluyor, ardından puan özeti ve son yorumlar kendi uçlarından
/// geliyor. Profilin kendisi gelmeden o bölümler hiç istenmiyor.
///
/// **Tek bir hata durumu var:** `404` (yok ya da silinmiş) ile `403`
/// (görmeye yetkin yok) ekranda birebir aynı — hangisi olduğunu söylemek
/// bir hesabın var olup olmadığını sızdırırdı. Çağıranın verdiği ad bile bu
/// durumda çizilmiyor. Yalnızca geçici hatalarda (bağlantı, zaman aşımı,
/// sunucu) başlık aynı kalıyor ve *Tekrar Dene* çıkıyor.
///
/// Kendi kimliğiyle açılırsa profil sekmesine yönleniyor: kendi profilinin
/// "başkasının gözüyle" görünümü ayrı bir ekran değil.
class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.args,
    this.userService,
    this.reviewService,
  });

  /// Rota `extra`'sından sayfayı kurar: [PublicProfileArgs] ya da yalnız
  /// kullanıcı kimliği.
  factory PublicProfilePage.fromExtra(Object? extra) {
    if (extra is PublicProfileArgs) {
      return PublicProfilePage(args: extra);
    }
    if (extra is String) {
      return PublicProfilePage(args: PublicProfileArgs(userId: extra));
    }
    throw ArgumentError.value(
      extra,
      'extra',
      'PublicProfileArgs veya kullanıcı kimliği bekleniyor',
    );
  }

  final PublicProfileArgs args;

  /// Testler için; verilmezse üretimdeki tekil servisler.
  final UserService? userService;
  final ReviewService? reviewService;

  static const String title = 'Profil';

  /// Tek hata durumunun başlığı; `404`, `403` ve geçici hatada aynı.
  static const String unavailableTitle = 'Profil görüntülenemiyor';

  /// `404`/`403`: iki sebebi de söylüyor, hangisi olduğunu söylemiyor.
  static const String unavailableNote =
      'Bu profil silinmiş ya da erişiminize kapalı olabilir.';

  /// Geçici hata: sebep kişide değil, tekrar denemek işe yarayabilir.
  static const String retryNote =
      'Profil şu an yüklenemedi. Biraz sonra tekrar deneyin.';

  /// Hiç değerlendirmesi olmayan birinin yorum bölümü; sahibine değil,
  /// başkasına konuşuyor.
  static const String noReviewsNote = 'Henüz değerlendirme yok.';

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends PublicProfilePagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: PublicProfilePage.title),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (failure != null) return _unavailable();
    // Kendi profili: sekmeye yönleniyor; o ana kadar çizilecek bir şey yok.
    if (isRedirecting || (isLoading && widget.args.name == null)) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          ProfileCover(
            name: displayName,
            imageUrl: photoUrl,
            subtitle: profile?.jobTitle,
            roleLabel: widget.args.role.label,
            location: profile?.locationLabel,
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.spaceLarge),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            _sections(context, profile!),
        ],
      ),
    );
  }

  /// Profil geldikten sonraki bölümler.
  Widget _sections(BuildContext context, PublicProfile loaded) {
    final about = loaded.about;

    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.args.companyName != null) ...[
            _companyRow(context),
            const SizedBox(height: AppSizes.spaceLarge),
          ],
          // Boş bir "hakkında" kartı başkasının profilinde bir şey söylemiyor.
          if (about != null && about.isNotEmpty) ...[
            _aboutSection(context, about),
            const SizedBox(height: AppSizes.spaceLarge),
          ],
          ProfileReviews(
            userId: widget.args.userId,
            service: widget.reviewService,
            emptyMessage: PublicProfilePage.noReviewsNote,
          ),
          const SizedBox(height: AppSizes.spaceLarge),
        ],
      ),
    );
  }

  Widget _aboutSection(BuildContext context, String about) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hakkında',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSizes.spaceSmall),
        Container(
          width: double.infinity,
          padding: AppPadding.primaryAll,
          decoration: BoxDecoration(
            color: context.tileColor,
            borderRadius: AppRadius.innerCircular,
          ),
          child: Text(
            about,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// Kişinin temsil ettiği şirket; kimliği biliniyorsa şirket sayfasına
  /// bağlantı.
  Widget _companyRow(BuildContext context) {
    final companyId = widget.args.companyId;
    final tappable = companyId != null;

    final content = Padding(
      padding: AppPadding.primaryAll,
      child: Row(
        children: [
          AppIcon(
            AppIcons.building,
            size: AppSizes.iconMedium,
            color: context.accentColor,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Şirket',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSizes.smallGap),
                Text(
                  widget.args.companyName!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tappable ? context.accentColor : null,
                  ),
                ),
              ],
            ),
          ),
          if (tappable)
            AppIcon(
              AppIcons.arrowRight,
              size: AppSizes.iconMedium,
              color: context.accentColor,
            ),
        ],
      ),
    );

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: tappable
          ? InkWell(
              key: const ValueKey('public-profile-company'),
              borderRadius: AppRadius.innerCircular,
              onTap: () => context.push('/company-detail', extra: companyId),
              child: content,
            )
          : content,
    );
  }

  /// Tek hata durumu. Kesin retlerde (`404`/`403`) tekrar deneme yok: sonuç
  /// değişmeyecek ve düğme bir şeyin geçici olduğunu ima ederdi.
  Widget _unavailable() {
    return EmptyState(
      icon: AppIcons.user,
      title: PublicProfilePage.unavailableTitle,
      description: isRefused
          ? PublicProfilePage.unavailableNote
          : PublicProfilePage.retryNote,
      action: isRefused
          ? null
          : OutlinedButton(onPressed: load, child: const Text('Tekrar Dene')),
    );
  }
}
