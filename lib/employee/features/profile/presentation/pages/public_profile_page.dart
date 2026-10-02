import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/employee/features/home/services/job_service.dart';
import 'package:koala/employee/features/jobs/models/rating_summary.dart';
import 'package:koala/employee/features/jobs/services/review_service.dart';
import 'package:koala/employee/features/profile/models/public_profile_args.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_reviews.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/profile_cover.dart';
import 'package:koala/product/widgets/report_sheet.dart';
import 'package:provider/provider.dart';

part 'public_profile_pagemodel.dart';

/// Çalışanın başka bir kullanıcının herkese açık profilini gördüğü sayfa
/// (is-koala/koala#182): grup sohbetinin katılımcısı ya da bireysel ilanın
/// işvereni.
///
/// İki kez çiziliyor: [PublicProfileArgs] çağıranın bildiği ad, fotoğraf ve
/// rolle kapağı hemen çiziyor; `GET /users/{id}` gelince meslek, konum ve
/// hakkında doluyor, ardından son yorumlar kendi ucundan geliyor (puan özeti
/// profil yanıtında zaten var). Profilin kendisi gelmeden yorum ve ilan uçları
/// hiç istenmiyor.
///
/// **Tek bir hata durumu var:** yok ya da silinmiş (`404`) ile görmeye yetkisiz
/// (`403`) ekranda birebir aynı — bu **savunmacı bir eşitlik**: bugün
/// `GET /users/{id}` hiç `403` üretmiyor, giriş yapmış herkes var olan her
/// kullanıcıyı görüyor, yani bugün gerçekte yalnız `404` görünür. İleride bir
/// görünürlük kuralı gelirse hangisi olduğunu söylemek bir hesabın var olup
/// olmadığını sızdırırdı; ekran şimdiden ayırt etmiyor. Çağıranın verdiği ad
/// bile bu durumda çizilmiyor. Yalnızca geçici hatalarda (bağlantı, zaman
/// aşımı, sunucu) başlık aynı kalıyor ve *Tekrar Dene* çıkıyor.
///
/// Kendi kimliğiyle açılırsa profil sekmesine yönleniyor: kendi profilinin
/// "başkasının gözüyle" görünümü ayrı bir ekran değil.
///
/// Başlıktaki şikayet eylemi mevcut [ReportSheet]'i açıyor: grup sohbetinde
/// şikayet/engelle yok, bu çalışanın ekip arkadaşını ya da şirket yetkilisini
/// bildirebileceği yer. Engelleme yok — sunucu grupta engeli uygulamıyor.
class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.args,
    this.userService,
    this.reviewService,
    this.jobService,
  });

  /// Rotadan sayfayı kurar. Kimlik **yol parametresi** ([userId]); [extra]
  /// yalnızca kapağı önceden doldurmak için ve yalnızca aynı kişiye aitse
  /// kullanılıyor — eksik, başka türde ya da başka bir kişinin `extra`'sı
  /// sayfayı açılmaktan alıkoymuyor.
  factory PublicProfilePage.fromRoute({
    Key? key,
    required String userId,
    Object? extra,
  }) {
    final prefill = extra is PublicProfileArgs && extra.userId == userId
        ? extra
        : PublicProfileArgs(userId: userId);
    return PublicProfilePage(key: key, args: prefill);
  }

  final PublicProfileArgs args;

  /// Testler için; verilmezse üretimdeki tekil servisler.
  final UserService? userService;
  final ReviewService? reviewService;
  final JobService? jobService;

  static const String title = 'Profil';

  /// Tek hata durumunun başlığı; kesin retlerde ve geçici hatada aynı.
  static const String unavailableTitle = 'Profil görüntülenemiyor';

  /// Kesin ret (`404`; savunmacı olarak `403` de): iki sebebi de söylüyor,
  /// hangisi olduğunu söylemiyor.
  static const String unavailableNote =
      'Bu profil silinmiş ya da erişiminize kapalı olabilir.';

  /// Geçici hata: sebep kişide değil, tekrar denemek işe yarayabilir.
  static const String retryNote =
      'Profil şu an yüklenemedi. Biraz sonra tekrar deneyin.';

  /// Şirket satırının boyutunun açılma süresi.
  static const Duration companyRevealDuration = Duration(milliseconds: 200);

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
      appBar: MyAppbar(
        title: PublicProfilePage.title,
        actions: [?_reportAction()],
      ),
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
          _companySlot(context),
          // Boş bir "hakkında" kartı başkasının profilinde bir şey söylemiyor.
          if (about != null && about.isNotEmpty) ...[
            _aboutSection(context, about),
            const SizedBox(height: AppSizes.spaceLarge),
          ],
          ProfileReviews(
            userId: widget.args.userId,
            service: widget.reviewService,
            emptyMessage: PublicProfilePage.noReviewsNote,
            // Özet profil yanıtında zaten geldi; ayrı uç çağrılmıyor.
            summary: ratingSummary,
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

  /// Kişinin temsil ettiği şirket (sohbetin ilanından çözüldü); şirket
  /// sayfasına bağlantı.
  Widget _companyRow(BuildContext context, JobCompany company) {
    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        key: const ValueKey('public-profile-company'),
        borderRadius: AppRadius.innerCircular,
        onTap: () => context.push('/company-detail', extra: company.id),
        child: Padding(
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
                      company.name,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.arrowRight,
                size: AppSizes.iconMedium,
                color: context.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Şirket satırının yeri. Satır ikinci (ağır) ilan isteğinden sonra
  /// geliyor ve en üstte; aniden eklense "Hakkında" ile yorumlar aşağı
  /// sıçrardı. Boyut animasyonla açılıyor; genişlik sabit kalsın diye boşken
  /// de tam genişlikte, sıfır yükseklikli bir kutu duruyor.
  Widget _companySlot(BuildContext context) {
    final found = company;

    return AnimatedSize(
      duration: PublicProfilePage.companyRevealDuration,
      alignment: Alignment.topCenter,
      child: found == null
          ? const SizedBox(width: double.infinity)
          : Column(
              children: [
                _companyRow(context, found),
                const SizedBox(height: AppSizes.spaceLarge),
              ],
            ),
    );
  }

  /// Başlıktaki şikayet düğmesi; yalnız profil geldikten sonra. Beklerken
  /// (derin bağlantıda, önceden doldurma yokken) form açılsa ve profil sonra
  /// `404` dönse kullanıcı var olmayan birini bildirmiş olurdu; hata ve
  /// yönlendirmede de bildirilecek bir profil yok.
  Widget? _reportAction() {
    if (profile == null || failure != null || isRedirecting) return null;

    return IconButton(
      tooltip: 'Şikayet Et',
      icon: AppIcon(AppIcons.flag, color: context.textPrimary),
      onPressed: () => ReportSheet.show(
        context,
        ReportTarget.user(userId: widget.args.userId, name: displayName),
      ),
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
