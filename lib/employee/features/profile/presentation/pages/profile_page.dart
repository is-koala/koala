import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/experience.dart';
import 'package:koala/employee/features/auth/models/user_badge.dart';
import 'package:koala/employee/features/auth/models/education.dart';
import 'package:koala/employee/features/profile/presentation/widgets/education_sheet.dart';
import 'package:koala/employee/features/profile/services/education_service.dart';
import 'package:koala/employee/features/profile/presentation/widgets/timeline_card.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:koala/employee/features/profile/presentation/widgets/experience_sheet.dart';
import 'package:koala/employee/features/profile/presentation/widgets/profile_reviews.dart';
import 'package:koala/employee/features/profile/services/experience_service.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:provider/provider.dart';

part 'profile_pagemodel.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ProfilePageModel {
  /// Profil fotoğrafının kenar uzunluğu.
  static const double _avatarSize = 100;

  /// Rozet şeridinin yüksekliği; rozetler kare görseller.
  static const double _badgeStripHeight = 150;

  /// Navbar'ın altında kalmasın diye sayfanın sonuna eklenen pay.
  static const double _bottomClearance = AppSizes.navBarClearance;

  /// Hata durumundaki ikon; boş durum ekranlarındaki ölçüyle aynı.
  static const double _errorIconSize = 64;

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
          IconButton(
            onPressed: () => context.push('/followed-companies'),
            icon: AppIcon(AppIcons.building, color: context.textPrimary),
            tooltip: 'Takip ettiklerim',
          ),
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
              cvArea(user),
              const SizedBox(height: AppSizes.spaceLarge),
              rosettes(user),
              experienceSection(user),
              const SizedBox(height: AppSizes.spaceMedium),
              educationSection(user),
              const SizedBox(height: AppSizes.spaceMedium),
              ProfileReviews(userId: user.id),
              const SizedBox(height: _bottomClearance),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadCv() async {
    final selection = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );
    final path = selection?.path;
    if (path == null || !mounted) return;

    final provider = context.read<UserProvider>();
    final uploaded = await provider.uploadCv(path);
    if (!mounted) return;
    if (uploaded) {
      AppToast.success(context, 'Özgeçmişin yüklendi.');
    } else {
      AppToast.error(context, provider.errorMessage ?? 'Özgeçmiş yüklenemedi.');
    }
  }

  Future<void> _deleteCv() async {
    final provider = context.read<UserProvider>();
    final deleted = await provider.deleteCv();
    if (!mounted) return;
    if (deleted) {
      AppToast.success(context, 'Özgeçmişin kaldırıldı.');
    } else {
      AppToast.error(
        context,
        provider.errorMessage ?? 'Özgeçmiş kaldırılamadı.',
      );
    }
  }

  Future<void> _showCvActions(CurrentUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(
                user.cvUrl == null ? 'Özgeçmiş Yükle' : 'Özgeçmişi Değiştir',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _uploadCv();
              },
            ),
            if (user.cvUrl != null && user.cvUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Özgeçmişi Kaldır'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteCv();
                },
              ),
          ],
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
        const SizedBox(height: AppSizes.spaceLarge),
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
        const SizedBox(height: AppSizes.spaceTiny),
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
            return TimelineCard(
              title: experience.title,
              subtitle: experience.subtitle,
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

  /// Öğrenim kayıtları.
  ///
  /// Deneyim bölümüyle aynı kurgu: boşken de çiziliyor ki kullanıcı
  /// ekleyebileceğini görsün.
  Widget educationSection(CurrentUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionTitle("Eğitim"),
            const Spacer(),
            IconButton(
              onPressed: _addEducation,
              icon: Icon(Icons.add, color: context.accentColor),
              tooltip: 'Eğitim ekle',
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spaceTiny),
        if (user.educations.isEmpty)
          Text(
            'Henüz bir eğitim eklemedin.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textTertiary,
            ),
          )
        else
          ...user.educations.asMap().entries.map((entry) {
            final education = entry.value;
            return TimelineCard(
              title: education.universityName ?? 'Üniversite',
              subtitle: education.subtitle,
              subtitleIcon: Icons.school,
              duration: _educationDuration(education),
              description: '',
              isLast: entry.key == user.educations.length - 1,
              onEdit: () => _editEducation(education),
              onDelete: () => _deleteEducation(education),
            );
          }),
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
        // Yetkinlik ve ilgi alanı, tanıtım yazısının aksine **boşken hiç
        // çizilmiyor**: ikisi de isteğe bağlı ve profili üç boş başlıkla
        // karşılamak kullanıcıya eksik bırakmış hissi veriyor.
        ?_textSection("Yetkinlikler", user.qualifications),
        ?_textSection("İlgi Alanları", user.interests),
      ],
    );
  }

  /// Doluysa başlık ve metni çizer, boşsa hiçbir şey döndürmez.
  Widget? _textSection(String title, String? value) {
    if (value == null || value.trim().isEmpty) return null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(value, style: context.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget cvArea(CurrentUser user) {
    return InkWell(
      key: const ValueKey('cv-actions'),
      onTap: () => _showCvActions(user),
      borderRadius: AppRadius.smallCircular,
      child: Container(
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
