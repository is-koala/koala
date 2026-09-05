import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/models/user_address.dart';
import 'package:koala/employee/features/auth/models/profile_update_result.dart';
import 'package:koala/employee/features/auth/models/public_profile.dart';
import 'package:koala/product/network/api_client.dart';
import 'package:koala/product/network/api_paths.dart';

/// `/users/me` uçlarının sarmalayıcısı.
///
/// [AuthService] ile aynı klasörde duruyor çünkü ikisi de aynı kullanıcı
/// kaydını okuyor: oturum açılırken tip öğrenilirken de, profil ekranı
/// çizilirken de yanıt aynı uçtan geliyor.
class UserService {
  UserService._(this._apiClient);

  static final UserService _instance = UserService._(ApiClient());

  factory UserService() => _instance;

  /// Verilen istemciyle kurulu örnek.
  ///
  /// Testlerde sahte sunucuya bağlamak için, [AuthService] içinde de aynı
  /// istemciyi paylaşmak için kullanılıyor.
  factory UserService.withClient(ApiClient apiClient) {
    return UserService._(apiClient);
  }

  final ApiClient _apiClient;

  /// Profil fotoğrafını yükler. Başarılı çağrıdan sonra kullanıcı yeniden
  /// çekilmelidir; backend bu uçta yalnızca başarı zarfı döndürüyor.
  Future<void> uploadProfilePicture(String filePath) {
    return _apiClient.putFileWithoutData(
      ApiPaths.currentUserProfilePicture,
      fieldName: 'image',
      filePath: filePath,
    );
  }

  /// PDF/DOC/DOCX özgeçmişi özel depoya yükler.
  Future<String> uploadCv(String filePath) {
    return _apiClient.putFile<String>(
      ApiPaths.currentUserCv,
      fieldName: 'file',
      filePath: filePath,
      parse: (data) => data! as String,
    );
  }

  Future<void> deleteCv() {
    return _apiClient.deleteWithoutData(ApiPaths.currentUserCv);
  }

  /// Oturum açmış kullanıcının bilgileri.
  Future<CurrentUser> fetchCurrentUser() {
    return _apiClient.get<CurrentUser>(
      ApiPaths.currentUser,
      parse: (data) => CurrentUser.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Başka bir kullanıcının herkese açık profili.
  ///
  /// Oturum açmış herkese açık; tam adres dönmüyor ve `cvUrl` yalnızca
  /// yetkili görene doluyor — kuralın tamamı [PublicProfile]'da.
  Future<PublicProfile> fetchPublicProfile(String userId) {
    return _apiClient.get<PublicProfile>(
      ApiPaths.publicProfile(userId),
      parse: (data) => PublicProfile.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Profil alanlarını kısmi olarak günceller.
  ///
  /// `null` geçilen parametre gövdeye hiç konmuyor — backend gönderilmeyen
  /// alana dokunmuyor. Bir alanı temizlemek için `null` değil boş metin
  /// gönderilmeli.
  ///
  /// İki tuzak var:
  /// - [email] ya da [phoneNumber] değiştirildiğinde değer hemen yazılmıyor;
  ///   yanıttaki `pendingVerifications` doluysa kullanıcı doğrulamayı
  ///   tamamlayana kadar eski değer geçerli.
  /// - Kimliği doğrulanmış kullanıcı ad, soyad ve doğum tarihini
  ///   değiştiremiyor; backend isteği reddediyor.
  Future<ProfileUpdateResult> updateProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? email,
    DateTime? birthDate,
    Gender? gender,
    String? jobTitle,
    String? about,
    String? qualifications,
    String? interests,
    String? iban,
  }) {
    final body = <String, dynamic>{
      'firstName': ?firstName,
      'lastName': ?lastName,
      'phoneNumber': ?phoneNumber,
      'email': ?email,
      // Backend'deki alan adı bilerek küçük `d` ile: istek DTO'su
      // `birthdate`, yanıt DTO'su `birthDate` kullanıyor.
      if (birthDate != null) 'birthdate': _asLocalDate(birthDate),
      'gender': ?gender?.code,
      'jobTitle': ?jobTitle,
      'about': ?about,
      'qualifications': ?qualifications,
      'interests': ?interests,
      // Sunucu IBAN'ı bu uçtan alıp birincil banka hesabına yazıyor; ayrı
      // bir uç yok. Yanıt IBAN'ı maskeli döndürüyor.
      'iban': ?iban,
    };

    return _apiClient.patch<ProfileUpdateResult>(
      ApiPaths.currentUser,
      body: body,
      parse: (data) =>
          ProfileUpdateResult.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// Kimliği doğrular.
  ///
  /// Sunucu bilgileri NVİ'ye soruyor; tutmazsa `400`, servise ulaşamazsa
  /// `502` dönüyor. Başarılıysa `/users/me`'deki `identityVerified` `true`
  /// oluyor — çağıran taraf kullanıcıyı tazelemeli.
  ///
  /// [tcIdentityNumber] 11 hane ve son hanesi çift olmak zorunda; sunucu
  /// deseni doğruluyor. [tcDocumentNumber] kimlik kartının üstündeki seri
  /// numarası.
  Future<void> verifyIdentity({
    required String firstName,
    required String lastName,
    required DateTime birthDate,
    required String tcIdentityNumber,
    required String tcDocumentNumber,
  }) {
    return _apiClient.postWithoutData(
      ApiPaths.currentUserIdentityVerification,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'birthDate': _asLocalDate(birthDate),
        'tcIdentityNumber': tcIdentityNumber,
        'tcDocumentNumber': tcDocumentNumber,
      },
    );
  }

  /// Adresi toptan değiştirir.
  ///
  /// Kısmi güncelleme değil: gönderilmeyen alan siliniyor. Koordinat
  /// **zorunlu** — sunucu `latitude`/`longitude` olmadan kabul etmiyor.
  Future<UserAddress> updateAddress({
    required String countryCode,
    required String cityName,
    required String addressLine,
    required double latitude,
    required double longitude,
    String? districtName,
    String? postalCode,
  }) {
    return _apiClient.put<UserAddress>(
      ApiPaths.currentUserAddress,
      body: {
        'countryCode': countryCode,
        'cityName': cityName,
        'districtName': ?districtName,
        'addressLine': addressLine,
        'postalCode': ?postalCode,
        'latitude': latitude,
        'longitude': longitude,
      },
      parse: (data) => UserAddress.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// `LocalDate` beklendiği için saat kısmı olmadan `yyyy-MM-dd`.
  static String _asLocalDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
