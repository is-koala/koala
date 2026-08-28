import 'package:koala/employee/features/auth/models/current_user.dart';
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
    };

    return _apiClient.patch<ProfileUpdateResult>(
      ApiPaths.currentUser,
      body: body,
      parse: (data) =>
          ProfileUpdateResult.fromJson(data! as Map<String, dynamic>),
    );
  }

  /// `LocalDate` beklendiği için saat kısmı olmadan `yyyy-MM-dd`.
  static String _asLocalDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
