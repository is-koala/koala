import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/profile/models/user.dart';
import 'package:koala/employee/features/profile/presentation/widgets/experience_card.dart';
import 'package:koala/employee/features/profile/services/fake_user.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';

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

  late User user;

  @override
  void initState() {
    super.initState();
    user = FakeUser.instance;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ayarlardan döndüğünde güncel veriyi al
    setState(() {
      user = FakeUser.instance;
    });
  }

  void _navigateToAccountInfo() async {
    final updatedUser = await context.push<User>('/account-info', extra: user);
    if (updatedUser != null) {
      setState(() {
        user = updatedUser;
        // Fake user'ı da güncelle ki uygulama genelinde tutarlı olsun
        FakeUser.instance.fullName = updatedUser.fullName;
        FakeUser.instance.jobTitle = updatedUser.jobTitle;
        FakeUser.instance.location = updatedUser.location;
        FakeUser.instance.about = updatedUser.about;
        FakeUser.instance.cvFileName = updatedUser.cvFileName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(
        title: "Profilim",
        isLarge: true,
        showBackButton: false,
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/settings');
              // Ayarlardan döndüğünde profili güncelle
              setState(() {
                user = FakeUser.instance;
              });
            },
            icon: AppIcon(AppIcons.settings, color: context.textPrimary),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileHeader(),
              const SizedBox(height: AppSizes.spaceLarge),
              aboutProfile(),
              const SizedBox(height: AppSizes.spaceLarge),
              cvArea(),
              const SizedBox(height: AppSizes.spaceXLarge),
              rosettes(),
              const SizedBox(height: AppSizes.spaceXLarge),
              experienceSection(),
              const SizedBox(height: _bottomClearance),
            ],
          ),
        ),
      ),
    );
  }

  Widget editProfileButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _navigateToAccountInfo,
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

  Column aboutProfile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Hakkımda"),
        const SizedBox(height: AppSizes.spaceTiny),
        Text(user.about, style: context.textTheme.bodyMedium),
      ],
    );
  }

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
                user.cvFileName,
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

  Row profileHeader() {
    return Row(
      children: [
        Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: AppRadius.secondaryCircular,
            image: DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage(user.profileImage),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spaceLarge),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.fullName,
              style: context.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(user.jobTitle, style: context.textTheme.bodyMedium),
            Text(user.location, style: context.textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
  );

  Column experienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Tecrübe"),
        const SizedBox(height: AppSizes.space),
        ...user.experiences.asMap().entries.map((entry) {
          final index = entry.key;
          final exp = entry.value;
          return ExperienceCard(
            title: exp.title,
            company: exp.company,
            duration: exp.duration,
            description: exp.description,
            isLast: index == user.experiences.length - 1,
          );
        }),
      ],
    );
  }
}
