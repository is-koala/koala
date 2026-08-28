/// Backend uç noktalarının yolları.
///
/// Tek yerde durmalarının sebebi, [AuthInterceptor]'ın "bu yol token ister mi"
/// sorusunu string kopyalamadan yanıtlayabilmesi.
class ApiPaths {
  // --------------------------------------------------------------------- Auth

  static const String startRegistration = '/auth/start-registration';
  static const String verifyRegistrationToken =
      '/auth/verify-registration-token';
  static const String completeRegistration = '/auth/complete-registration';
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // -------------------------------------------------------------------- Users

  static const String currentUser = '/users/me';
  static const String currentUserPassword = '/users/me/password';
  static const String currentUserProfilePicture = '/users/me/profile-picture';
  static const String currentUserAddress = '/users/me/address';

  // --------------------------------------------------------------------- Jobs

  static const String jobs = '/jobs';

  /// Tek ilanın detayı.
  static String job(String jobId) => '$jobs/$jobId';

  /// Bir ilana başvurma.
  static String jobApplications(String jobId) => '$jobs/$jobId/applications';

  /// Oturum açmış kullanıcının başvuruları.
  static const String myApplications = '/users/me/applications';

  /// Kabul edilmiş başvuruların dönüştüğü işler.
  static const String myAssignments = '/users/me/assignments';

  /// Kaydedilen ilanlar.
  static const String savedJobs = '/users/me/saved-jobs';

  /// Tek bir ilanı kaydetme / kaydı kaldırma.
  static String savedJob(String jobId) => '$savedJobs/$jobId';

  // ----------------------------------------------------------------- İşveren

  /// Oturum sahibinin açtığı ilanlar. Bireysel ve kurumsal ilanların ikisi de
  /// burada: backend `creatorId`'ye bakıyor, şirkete değil.
  static const String myJobs = '/users/me/jobs';

  /// Bireysel ilan açma. Kurumsal ilan [companyJobs] üzerinden gidiyor.
  static const String createIndividualJob = myJobs;

  /// Şirket adına ilan açma.
  static String companyJobs(String companyId) => '/companies/$companyId/jobs';

  /// İlanı başvuruya kapatma. Silme ucu yok — bkz. `b_posts_page`.
  static String closeJob(String jobId) => '${job(jobId)}/close';

  /// Bir başvuruyu kabul etme ya da reddetme.
  static String respondToApplication(String applicationId) =>
      '/job-applications/$applicationId/respond';

  // ---------------------------------------------------------------- Sohbet

  static const String conversations = '/conversations';

  /// Bir ilan üzerinden sohbet açar. Sohbet daima ilana bağlı.
  static String jobConversation(String jobId) => '$jobs/$jobId/conversation';

  static String conversationMessages(String conversationId) =>
      '$conversations/$conversationId/messages';

  static String conversationRead(String conversationId) =>
      '$conversations/$conversationId/read';

  /// Birden çok kullanıcının çevrimiçi durumu, tek istekte.
  static const String presenceLookup = '/presence/lookup';

  // ---------------------------------------------------------- Reference data

  static const String jobCategories = '/reference/job-categories';

  /// Ülkeler. İl/ilçe seçicisi buradan başlıyor.
  static const String countries = '/reference/countries';

  /// Bir ülkenin illeri.
  static String cities(String countryId) => '$countries/$countryId/cities';

  /// Bir ilin ilçeleri. Yol `/reference/cities/...` — [cities] ile
  /// karıştırılmamalı, o ülke altında.
  static String districts(String cityId) =>
      '/reference/cities/$cityId/districts';

  // -------------------------------------------------------------------- Legal

  static const String agreements = '/legal/agreements';
  static const String consents = '/legal/consents';
  static const String accountDeletion = '/legal/account-deletion';

  /// Token taşımadan çağrılan uçlar. Bunların dışındaki her isteğe
  /// `Authorization` başlığı ekleniyor.
  ///
  /// [refreshToken] bilerek listede değil: backend oturum kimliğini süresi
  /// dolmuş erişim token'ından okuduğu için o çağrı da başlığı taşımalı.
  static const Set<String> publicPaths = {
    startRegistration,
    verifyRegistrationToken,
    completeRegistration,
    login,
    forgotPassword,
    resetPassword,
    agreements,
    // `/reference/**` GET'leri backend'de `permitAll`. İl/ilçe uçlarının yolu
    // değişken olduğu için bu kümeye giremiyor; token taşımaları zararsız,
    // yalnızca oturum açmış işveren çağırıyor.
    jobCategories,
    countries,
  };
}
