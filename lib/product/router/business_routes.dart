/// İşveren kabuğunun birden çok yerden açılan rotaları.
///
/// Yol dizgesi tek yerde dursun diye: aynı rota başvuran kartından, yetenek
/// havuzundan ve grup sohbetinin katılımcı listesinden açılıyor.
/// `RouterManager` rotayı buradan kuruyor; çağıranlar `context.push` ile
/// buraya gidiyor.
class BusinessRoutes {
  const BusinessRoutes._();

  /// Bir adayın profili. `extra`: `JobApplicant` ya da kullanıcı kimliği
  /// (`String`) — `BUserProfilePage.fromExtra` ikisini de kabul ediyor.
  static const String userProfile = '/business/user-profile';
}
