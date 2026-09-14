part of 'profile_page.dart';

/// Profil ekranının durumu ve sunucu çağrıları.
///
/// Ekran iki bölümlü: burada veri ve eylemler, `profile_page.dart`'ta
/// yalnızca çizim. Deneyim ve eğitim CRUD'u eklenince tek dosya
/// CONTRIBUTING'in ayırma eşiğini geçmişti.
abstract class ProfilePageModel extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin<ProfilePage> {
  final ExperienceService _experienceService = ExperienceService();

  final EducationService _educationService = EducationService();

  @override
  void initState() {
    super.initState();
    // Sayfa `ShellPage`'in `PageView`'ında bir kez kurulup canlı kaldığı için
    // ilk kare çizildikten sonra tek seferlik yükleme yapılıyor; sekmeye her
    // dönüşte `initState` çalışmıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProfileData();
    });
  }

  Future<void> _loadProfileData({bool silent = false}) async {
    final userProvider = context.read<UserProvider>();
    // Kimlik inceleme durumu her açılışta ve yenilemede tazeleniyor: personel
    // kararı (red/onay) bu ekranın rozetinde görünmeli, açılıştaki tek
    // okumada kalmamalı. Kullanıcı yüklemesini bekletmiyor.
    unawaited(context.read<IdentityReviewProvider>().load(silent: true));
    await userProvider.load(silent: silent);
    if (!mounted) return;

    final user = userProvider.user;
    if (user != null) {
      await context.read<AvailabilityProvider>().load(user.id, silent: silent);
    }
  }

  Future<void> _refreshProfile() => _loadProfileData(silent: true);

  Future<void> _navigateToAccountInfo(CurrentUser user) async {
    await context.push(AccountRoutes.accountInfo, extra: user);
    // Düzenleme ekranı kaydı doğrudan provider üzerinden güncelliyor; burada
    // yalnızca ekranın açık kaldığı sürede sunucuda değişen bir şey varsa
    // yakalamak için sessiz tazeleme yapılıyor.
    if (mounted) await context.read<UserProvider>().load(silent: true);
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

  Future<void> _showCvActions(CurrentUser user) {
    final hasCv = user.cvUrl?.isNotEmpty ?? false;
    return CvActionsSheet.show(
      context,
      hasCv: hasCv,
      onUpload: _uploadCv,
      onDelete: _deleteCv,
    );
  }

  /// Sekme değiştikçe sayfa yeniden kurulmasın: `initState`'teki tek seferlik
  /// yükleme ancak böyle tek sefer kalıyor, kaydırma konumu da korunuyor.
  @override
  bool get wantKeepAlive => true;

  /// Tarih aralığı ve kademe. Not ortalaması varsa o da ekleniyor —
  /// girilmemişse hiç yazılmıyor, "0.0" kötü not gibi okunurdu.
  String _educationDuration(Education education) {
    final parts = <String>[
      education.durationLabel,
      education.type.displayName,
      if (education.gpa != null) 'GNO ${education.gpa!.toStringAsFixed(2)}',
    ];

    return parts.where((part) => part.isNotEmpty).join(' · ');
  }

  Future<void> _addEducation() async {
    final result = await EducationSheet.show(context);
    if (result == null || !mounted) return;

    await _saveEducation(
      () => _educationService.create(
        universityId: result.universityId,
        facultyId: result.facultyId,
        departmentId: result.departmentId,
        type: result.type,
        startDate: result.startDate,
        gpa: result.gpa,
        endDate: result.endDate,
      ),
      successMessage: 'Eğitim eklendi',
    );
  }

  Future<void> _editEducation(Education education) async {
    final result = await EducationSheet.show(context, initial: education);
    if (result == null || !mounted) return;

    await _saveEducation(
      () => _educationService.update(
        educationId: education.id,
        universityId: result.universityId,
        facultyId: result.facultyId,
        departmentId: result.departmentId,
        type: result.type,
        startDate: result.startDate,
        gpa: result.gpa,
        endDate: result.endDate,
      ),
      successMessage: 'Eğitim güncellendi',
    );
  }

  /// Kaydı siler. Geri alınamıyor, önce onay soruluyor.
  Future<void> _deleteEducation(Education education) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Eğitimi sil',
      message:
          '"${education.universityName ?? 'Bu kayıt'}" silinecek ve geri '
          'alınamayacak.',
      actionLabel: 'Sil',
    );

    if (confirmed != true || !mounted) return;

    await _saveEducation(
      () => _educationService.delete(education.id),
      successMessage: 'Eğitim silindi',
    );
  }

  /// Ekleme, güncelleme ve silmenin ortak gövdesi.
  ///
  /// Eğitimler `/users/me` yanıtından okunuyor; her değişiklikten sonra
  /// kullanıcı tazeleniyor, dönen kayıt tek başına listeye yamanmıyor.
  Future<void> _saveEducation(
    Future<void> Function() call, {
    required String successMessage,
  }) async {
    try {
      await call();
      if (!mounted) return;
      await context.read<UserProvider>().load(silent: true);
      if (mounted) AppToast.success(context, successMessage);
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    }
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Deneyimi sil',
      message: '"${experience.title}" kaydı silinecek ve geri alınamayacak.',
      actionLabel: 'Sil',
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
}
