part of 'public_profile_page.dart';

abstract class PublicProfilePagemodel extends State<PublicProfilePage> {
  UserService get _userService => widget.userService ?? UserService();

  /// Sunucudaki profil; gelene kadar `null`.
  PublicProfile? profile;

  bool isLoading = true;

  /// Profil çekilemediyse sebebi. Ekranda sebep değil yalnız *kesin mi,
  /// geçici mi* ayrımı kullanılıyor ([isRefused]).
  ApiException? failure;

  /// Kendi profili açıldı, profil sekmesine yönleniyor.
  bool isRedirecting = false;

  /// Sunucu bu profili vermiyor: yok/silinmiş (`404`) ya da görme yetkisi yok
  /// (`403`). İkisi aynı ekranı çiziyor ve tekrar denemek bir şey
  /// değiştirmiyor.
  bool get isRefused {
    final type = failure?.type;
    return type == ApiErrorType.notFound || type == ApiErrorType.forbidden;
  }

  /// Kapaktaki ad: sunucunun söylediği, yoksa çağıranın verdiği.
  String get displayName {
    final fromProfile = profile?.fullName;
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    return widget.args.name ?? '';
  }

  /// Profil geldiyse fotoğrafın tek kaynağı o: kişi fotoğrafını kaldırdıysa
  /// çağıranın elindeki eski bağlantı geri gelmiyor.
  String? get photoUrl {
    final loaded = profile;
    return loaded == null ? widget.args.imageUrl : loaded.profilePictureUrl;
  }

  @override
  void initState() {
    super.initState();
    if (_isOwnProfile) {
      isRedirecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(EmployeeRoutes.ownProfile);
      });
      return;
    }
    load();
  }

  bool get _isOwnProfile =>
      widget.args.userId == context.read<UserProvider>().user?.id;

  Future<void> load() async {
    setState(() {
      isLoading = true;
      failure = null;
    });

    try {
      final fetched = await _userService.fetchPublicProfile(widget.args.userId);
      if (!mounted) return;
      setState(() {
        profile = fetched;
        isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        failure = error;
        isLoading = false;
      });
    }
  }
}
