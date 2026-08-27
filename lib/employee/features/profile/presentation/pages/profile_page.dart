import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
    final provider = context.watch<UserProvider>();
    final user = provider.user;

    return Scaffold(
      appBar: MyAppbar(
        title: "Profilim",
        isLarge: true,
        showBackButton: false,
        actions: [
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
              cvArea(),
              const SizedBox(height: AppSizes.spaceXLarge),
              rosettes(),
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

  /// TODO(backend): Rozetlerin karşılığı henüz yok; görseller sabit.
  Column rosettes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Rozetler"),
        SizedBox(
          height: _badgeStripHeight,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Image.asset(AppAssets.badgeGold),
              Image.asset(AppAssets.badgeSilverAlt),
            ],
          ),
        ),
      ],
    );
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

  /// TODO(backend): Özgeçmiş yükleme ucu yok; kart sabit metinle çiziliyor.
  Container cvArea() {
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
                "Henüz yüklenmedi",
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
    // "Meslek" alanının backend'deki karşılığı `qualifications`; ayrı bir
    // ünvan alanı yok.
    final occupation = user.qualifications;

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
