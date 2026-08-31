import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/profile/presentation/widgets/experience_card.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/employee/features/profile/presentation/widgets/experience_sheet.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_reviews.dart';
import 'package:koala/employee/features/profile/services/experience_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/notification_bell.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin<ProfilePage> {
  final ExperienceService _experienceService = ExperienceService();

  /// Profil fotoğrafının kenar uzunluğu.
  static const double _avatarSize = 100;

  /// Rozet şeridinin yüksekliği; rozetler kare görseller.
  static const double _badgeStripHeight = 150;

  /// Navbar'ın altında kalmasın diye sayfanın sonuna eklenen pay. Profilde
  /// liste değil tek sütun var, o yüzden standart paydan geniş.
  static const double _bottomClearance = 120;

  /// Hata durumundaki ikon; boş durum ekranlarındaki ölçüyle aynı.
  static const double _errorIconSize = 64;

  @override
  void initState() {
    super.initState();
    // Sayfa `ShellPage`'in `PageView`'ında bir kez kurulup canlı kaldığı için
    // ilk kare çizildikten sonra tek seferlik yükleme yapılıyor; sekmeye her
    // dönüşte `initState` çalışmıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UserProvider>().load();
    });
  }

  Future<void> _navigateToAccountInfo(CurrentUser user) async {
    await context.push('/account-info', extra: user);
    // Düzenleme ekranı kaydı doğrudan provider üzerinden güncelliyor; burada
    // yalnızca ekranın açık kaldığı sürede sunucuda değişen bir şey varsa
    // yakalamak için sessiz tazeleme yapılıyor.
    if (mounted) await context.read<UserProvider>().load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<UserProvider>();
    final user = provider.user;

    return Scaffold(
      appBar: MyAppbar(
        title: "Profilim",
        isLarge: true,
        showBackButton: false,
        actions: [
          const NotificationBell(route: '/notifications'),
          IconButton(
            onPressed: () async {
              await context.push('/settings');
              if (context.mounted) {
                await context.read<UserProvider>().load(silent: true);
              }
            },
            icon: AppIcon(AppIcons.settings, color: context.textPrimary),
          ),
        ],
      ),
      body: switch ((user, provider.isLoading, provider.errorMessage)) {
        (null, true, _) => const Center(child: CircularProgressIndicator()),
        (null, _, final String message) => _errorState(message),
        (null, _, _) => const SizedBox.shrink(),
        (final CurrentUser value, _, _) => _content(value),
      },
    );
  }

  /// Sekme değiştikçe sayfa yeniden kurulmasın: `initState`'teki tek seferlik
  /// yükleme ancak böyle tek sefer kalıyor, kaydırma konumu da korunuyor.
  @override
  bool get wantKeepAlive => true;

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.alert,
              size: _errorIconSize,
              color: context.dividerColor,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(
              onPressed: () => context.read<UserProvider>().load(),
              child: const Text("Tekrar Dene"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(CurrentUser user) {
    return RefreshIndicator(
      onRefresh: () => context.read<UserProvider>().load(silent: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileHeader(user),
              const SizedBox(height: AppSizes.spaceLarge),
              aboutProfile(user),
              const SizedBox(height: AppSizes.spaceLarge),
              cvArea(user),
              const SizedBox(height: AppSizes.spaceXLarge),
              rosettes(user),
              experienceSection(user),
              const SizedBox(height: AppSizes.spaceLarge),
              ProfileReviews(userId: user.id),
              const SizedBox(height: _bottomClearance),
            ],
          ),
        ),
      ),
    );
  }

  Widget editProfileButton(CurrentUser user) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _navigateToAccountInfo(user),
        icon: const Icon(Icons.edit, size: AppSizes.iconSmall),
        label: const Text("Profili Düzenle"),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.accentColor,
          side: BorderSide(color: context.accentColor),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.innerCircular,
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSizes.space),
          textStyle: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Kazanılan rozetler.
  ///
  /// Rozeti olmayan kullanıcıya boş bir şerit göstermek yerine bölüm hiç
  /// çizilmiyor; rozet kazanmak bir başarı, yokluğu vurgulanmamalı.
  Widget rosettes(CurrentUser user) {
    if (user.badges.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Rozetler"),
        SizedBox(
          height: _badgeStripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: user.badges.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSizes.spaceSmall),
            itemBuilder: (context, index) => _badge(user.badges[index]),
          ),
        ),
        const SizedBox(height: AppSizes.spaceXLarge),
      ],
    );
  }

  /// Tek rozet görseli.
  ///
  /// Uygulamada yalnızca Gezgin ailesinin altın ve gümüş görselleri var;
  /// diğerleri sunucudaki ikona düşüyor. İkisi de yoksa rozet adı yazılıyor,
  /// böylece kazanılmış bir rozet hiç görünmez olmuyor.
  Widget _badge(UserBadge badge) {
    final asset = badge.localAsset;
    final url = badge.iconUrl;

    final Widget visual;
    if (asset != null) {
      visual = Image.asset(asset);
    } else if (url != null && url.isNotEmpty) {
      visual = Image.network(
        url,
        errorBuilder: (_, _, _) => _badgeFallback(badge),
      );
    } else {
      visual = _badgeFallback(badge);
    }

    return Tooltip(message: badge.description ?? badge.name, child: visual);
  }

  Widget _badgeFallback(UserBadge badge) {
    return Center(
      child: Text(
        badge.name,
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          color: context.textSecondary,
        ),
      ),
    );
  }

  /// Deneyim listesi.
  ///
  /// Boşken de çiziliyor: eskiden bölüm hiç görünmüyordu ve kullanıcı
  /// deneyim ekleyebileceğini fark edemiyordu.
  Widget experienceSection(CurrentUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle("Tecrübe"),
            const Spacer(),
            IconButton(
              onPressed: _addExperience,
              icon: Icon(Icons.add, color: context.accentColor),
              tooltip: 'Deneyim ekle',
            ),
          ],
        ),
        const SizedBox(height: AppSizes.space),
        if (user.experiences.isEmpty)
          Text(
            'Henüz bir deneyim eklemedin.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          )
        else
          ...user.experiences.asMap().entries.map((entry) {
            final experience = entry.value;
            return ExperienceCard(
              title: experience.title,
              company: experience.subtitle,
              duration: experience.durationLabel,
              description: experience.description ?? '',
              isLast: entry.key == user.experiences.length - 1,
              onEdit: () => _editExperience(experience),
              onDelete: () => _deleteExperience(experience),
            );
          }),
      ],
    );
  }

  /// Deneyim ekler.
  Future<void> _addExperience() async {
    final result = await ExperienceSheet.show(context);
    if (result == null || !mounted) return;

    await _saveExperience(
      () => _experienceService.create(
        title: result.title,
        startDate: result.startDate,
        companyName: result.companyName,
        employmentType: result.employmentType,
        cityName: result.cityName,
        endDate: result.endDate,
        description: result.description,
      ),
      successMessage: 'Deneyim eklendi',
    );
  }

  /// Deneyimi düzenler.
  Future<void> _editExperience(Experience experience) async {
    final result = await ExperienceSheet.show(context, initial: experience);
    if (result == null || !mounted) return;

    await _saveExperience(
      () => _experienceService.update(
        experienceId: experience.id,
        title: result.title,
        startDate: result.startDate,
        companyName: result.companyName,
        employmentType: result.employmentType,
        cityName: result.cityName,
        endDate: result.endDate,
        description: result.description,
      ),
      successMessage: 'Deneyim güncellendi',
    );
  }

  /// Deneyimi siler. Geri alınamıyor, önce onay soruluyor.
  Future<void> _deleteExperience(Experience experience) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        title: Text('Deneyimi sil', style: dialogContext.textTheme.titleMedium),
        content: Text(
          '"${experience.title}" kaydı silinecek ve geri alınamayacak.',
          style: dialogContext.textTheme.bodyMedium?.copyWith(
            color: dialogContext.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _saveExperience(
      () => _experienceService.delete(experience.id),
      successMessage: 'Deneyim silindi',
    );
  }

  /// Ekleme, güncelleme ve silmenin ortak gövdesi.
  ///
  /// Deneyimler `/users/me` yanıtından okunuyor; her değişiklikten sonra
  /// kullanıcı tazeleniyor, dönen kayıt tek başına listeye yamanmıyor.
  Future<void> _saveExperience(
    Future<void> Function() call, {
    required String successMessage,
  }) async {
    try {
      await call();
      if (!mounted) return;
      AppToast.success(context, successMessage);
      await context.read<UserProvider>().load(silent: true);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, error.message);
    }
  }

  Column aboutProfile(CurrentUser user) {
    final about = user.about;
    final isEmpty = about == null || about.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Hakkımda"),
        const SizedBox(height: AppSizes.spaceTiny),
        Text(
          isEmpty ? "Henüz bir tanıtım yazısı eklemedin." : about,
          style: context.textTheme.bodyMedium?.copyWith(
            color: isEmpty ? context.textTertiary : null,
          ),
        ),
      ],
    );
  }

  /// Özgeçmiş kartı.
  ///
  /// TODO(backend): `PUT /users/me/cv` multipart bekliyor; dosya seçme akışı
  /// henüz yok, kart şimdilik yalnızca durumu gösteriyor.
  Container cvArea(CurrentUser user) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.spaceSmall,
        horizontal: AppSizes.spaceLarge,
      ),
      decoration: BoxDecoration(
        color: context.accentColor,
        borderRadius: AppRadius.smallCircular,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Özgeçmiş",
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.onAccentColor,
                ),
              ),
              Text(
                user.cvUrl == null || user.cvUrl!.isEmpty
                    ? "Henüz yüklenmedi"
                    : "Yüklendi",
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.onAccentColor,
                ),
              ),
            ],
          ),
          AppIcon(AppIcons.attachment, color: context.onAccentColor),
        ],
      ),
    );
  }

  Row profileHeader(CurrentUser user) {
    final location = user.address?.shortLabel;
    final occupation = user.jobTitle;

    return Row(
      children: [
        ProfileAvatar(imageUrl: user.profilePictureUrl, size: _avatarSize),
        const SizedBox(width: AppSizes.spaceLarge),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: context.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (occupation != null && occupation.isNotEmpty)
                Text(occupation, style: context.textTheme.bodyMedium),
              if (location != null)
                Text(location, style: context.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );
}
