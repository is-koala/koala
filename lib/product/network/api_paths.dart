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
  static const String currentUserCv = '/users/me/cv';
  static const String currentUserAddress = '/users/me/address';

  /// Kimlik doğrulama. Ad, soyad, doğum tarihi, TC kimlik ve belge numarası
  /// gönderiliyor; sunucu NVİ'ye soruyor.
  ///
  /// İlana başvurabilmenin ilk şartı bu — doğrulanmamış kullanıcının
  /// başvurusu `APPLICANT_IDENTITY_NOT_VERIFIED` ile reddediliyor.
  static const String currentUserIdentityVerification =
      '/users/me/identity-verification';

  /// Oturum sahibinin takip ettiği şirketler. Sayfalı.
  static const String followedCompanies = '/users/me/followed-companies';

  // ----------------------------------------------------------------- Eğitim

  /// Oturum sahibinin öğrenim kayıtları.
  ///
  /// Liste `/users/me` yanıtında da geliyor; bu uçlar ekleme, güncelleme ve
  /// silme için.
  static const String currentUserEducations = '/users/me/educations';

  static String currentUserEducation(String educationId) =>
      '$currentUserEducations/$educationId';

  /// Üniversite / fakülte / bölüm referans listeleri. Üçü de kimlik
  /// doğrulama istemiyor.
  static const String universities = '/reference/universities';

  static String universityFaculties(String universityId) =>
      '$universities/$universityId/faculties';

  static String facultyDepartments(String facultyId) =>
      '/reference/faculties/$facultyId/departments';

  // ---------------------------------------------------------------- Oturumlar

  /// Hesabın açık oturumları. `DELETE` isteği atan oturum hariç hepsini
  /// kapatıyor.
  static const String currentUserSessions = '/users/me/sessions';

  static String currentUserSession(String sessionId) =>
      '$currentUserSessions/$sessionId';

  // ------------------------------------------------------------- Bildirimler

  /// Oturum sahibinin bildirim akışı. Sayfalı; okunmamış sayısı da aynı
  /// yanıtta geliyor.
  static const String currentUserNotifications = '/users/me/notifications';

  /// Hepsini okundu işaretler ve kaç tanesinin işaretlendiğini döndürür.
  static const String currentUserNotificationsRead =
      '$currentUserNotifications/read';

  /// Tek bir bildirimi okundu işaretler. Zaten okunmuşsa ya da başkasına
  /// aitse sunucu sessizce geçiyor.
  static String currentUserNotificationRead(String notificationId) =>
      '$currentUserNotifications/$notificationId/read';

  // -------------------------------------------------------------------- Users

  /// Oturum sahibinin iş deneyimleri.
  ///
  /// Liste `/users/me` yanıtında da geliyor; bu uçlar tek tek ekleme,
  /// güncelleme ve silme için. Başkasının kaydına dokunmak `404`.
  static const String currentUserExperiences = '/users/me/experiences';

  static String currentUserExperience(String experienceId) =>
      '$currentUserExperiences/$experienceId';

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

  // ----------------------------------------------------------------- Atama

  static const String jobAssignments = '/job-assignments';

  /// Tek bir atama.
  static String jobAssignment(String assignmentId) =>
      '$jobAssignments/$assignmentId';

  /// Çalışanın atamayı kabul etmesi ya da reddetmesi.
  ///
  /// İşveren bir başvuruyu kabul ettiğinde atama `PENDING_CONFIRMATION`
  /// durumunda açılıyor ve iş, çalışan buradan onay verene kadar başlamıyor.
  /// Atama bu durumdan çıktıysa sunucu `409` döndürüyor.
  static String respondToAssignment(String assignmentId) =>
      '${jobAssignment(assignmentId)}/respond';

  /// Mesai başlatma ve bitirme. İkisini de yalnızca işi yapan kişi
  /// çağırabiliyor; konum gövdesi isteğe bağlı.
  ///
  /// Giriş, atamayı `IN_PROGRESS`'e çeviriyor. Para emanete alınmadan
  /// (`HELD_IN_ESCROW`) giriş yapılamıyor — sunucu `409` döndürüyor.
  static String assignmentCheckIn(String assignmentId) =>
      '${jobAssignment(assignmentId)}/check-in';

  static String assignmentCheckOut(String assignmentId) =>
      '${jobAssignment(assignmentId)}/check-out';

  /// Atamanın mesai oturumları. İki taraf da okuyabiliyor.
  static String assignmentWorkSessions(String assignmentId) =>
      '${jobAssignment(assignmentId)}/work-sessions';

  /// Atamayı iptal etme ve iptal kaydını okuma.
  ///
  /// İki taraf da iptal edebiliyor; kesinti oranı kimin iptal ettiğine ve
  /// işin başlamasına kalan süreye göre sunucuda hesaplanıyor. Gerekçe
  /// zorunlu. Atama başına tek kayıt: ikincisi `409`.
  ///
  /// Kesintiyi iptal öncesi öğrenmek için [assignmentCancellationPreview]
  /// kullanılıyor; oranların kendisi `/admin/settings` altında ve uygulamaya
  /// kapalı.
  static String cancelAssignment(String assignmentId) =>
      '${jobAssignment(assignmentId)}/cancel';

  static String assignmentCancellation(String assignmentId) =>
      '${jobAssignment(assignmentId)}/cancellation';

  /// İptal edilse ne kesileceğini, iptal **etmeden** döndürür.
  ///
  /// Kayıt oluşturmuyor. Uygun olmayan durumda hata değil
  /// `cancellableNow: false` dönüyor; taraf olmayan `404` alıyor.
  static String assignmentCancellationPreview(String assignmentId) =>
      '${jobAssignment(assignmentId)}/cancellation-preview';

  /// Atamanın uyuşmazlıkları: açma (`POST`) ve listeleme (`GET`).
  ///
  /// Yalnızca para emanetteyken açılabiliyor ve aynı anda tek açık
  /// uyuşmazlık olabiliyor; ikisi de `409`.
  static String assignmentDisputes(String assignmentId) =>
      '${jobAssignment(assignmentId)}/disputes';

  /// İşi tamamlanmış işaretleme.
  ///
  /// Yalnızca **işveren** çağırabiliyor: ilan sahibi ya da şirket yetkilisi.
  /// `CONFIRMED` ve `IN_PROGRESS` dışından çağrılırsa `409`.
  static String completeAssignment(String assignmentId) =>
      '${jobAssignment(assignmentId)}/complete';

  /// Tamamlanmış bir işin değerlendirmesi.
  ///
  /// Değerlendirme atamaya bırakılıyor ama karşı tarafa yazılıyor; okuması
  /// [userReviews] üzerinden. Her taraf bir kez yazabiliyor, ikincisi `409`.
  static String assignmentReviews(String assignmentId) =>
      '${jobAssignment(assignmentId)}/reviews';

  // ----------------------------------------------------------------- İşveren

  /// Oturum sahibinin açtığı ilanlar. Bireysel ve kurumsal ilanların ikisi de
  /// burada: backend `creatorId`'ye bakıyor, şirkete değil.
  static const String myJobs = '/users/me/jobs';

  /// Bireysel ilan açma. Kurumsal ilan [companyJobs] üzerinden gidiyor.
  static const String createIndividualJob = myJobs;

  /// Şirket adına ilan açma.
  static String companyJobs(String companyId) => '/companies/$companyId/jobs';

  /// İlanı başvuruya kapatma: yeni başvuru gelmez, ilan geçerliliğini korur.
  static String closeJob(String jobId) => '${job(jobId)}/close';

  /// İlanı iptal etme: ilan geçersiz olur ve başvuranlara bildirim gider.
  ///
  /// Silme değil — kayıt ve başvuru geçmişi duruyor. Devam eden bir iş
  /// ataması varken sunucu `409` döndürüyor; o durumda atamanın kendi iptal
  /// akışı kullanılmalı.
  static String cancelJob(String jobId) => '${job(jobId)}/cancel';

  /// Bir başvuruyu kabul etme ya da reddetme.
  static String respondToApplication(String applicationId) =>
      '/job-applications/$applicationId/respond';

  // ------------------------------------------------------------------ Şirket

  static const String companies = '/companies';

  /// Şirket detayı (GET) ve güncelleme (PATCH). Güncellemeyi yalnızca
  /// şirketin `ADMIN` yetkilisi yapabiliyor; üye olmayan 404 alıyor.
  static String company(String companyId) => '$companies/$companyId';

  /// Şirketi takip etme (`POST`) ve takibi bırakma (`DELETE`).
  ///
  /// Takip durumu ayrıca sorulmuyor: `GET /companies/{id}` yanıtı `following`
  /// alanını taşıyor.
  static String companyFollow(String companyId) =>
      '${company(companyId)}/follow';

  /// Şirketin galerisi.
  ///
  /// Şirket detayı görselleri zaten gövdesinde döndürüyor; bu uç yalnızca
  /// galeriyi tek başına yönetmek için.
  static String companyImages(String companyId) =>
      '${company(companyId)}/images';

  /// Şirketin yetkilileri.
  static String companyContacts(String companyId) =>
      '${company(companyId)}/contacts';

  /// Şirket logosu: `PUT` ile değiştiriliyor, `DELETE` ile kaldırılıyor.
  /// Yalnızca şirketin `ADMIN` yetkilisi çağırabiliyor.
  static String companyLogo(String companyId) => '${company(companyId)}/logo';

  // ------------------------------------------------------------- Kullanıcı

  /// Bir kullanıcının herkese açık profili.
  ///
  /// Tam adres dönmüyor, yalnızca il ve ilçe. `cvUrl` yalnızca kişinin
  /// kendisine ya da o kişinin başvurduğu bir ilanın işverenine doluyor.
  static String publicProfile(String userId) => '/users/$userId';

  /// Bir kullanıcı hakkında yazılmış değerlendirmeler. Sayfalı ve herkese
  /// açık.
  static String userReviews(String userId) =>
      '${publicProfile(userId)}/reviews';

  /// Bir kullanıcının puan özeti: ortalama ve değerlendirme sayısı.
  ///
  /// Hiç değerlendirilmemiş kullanıcı için `data: null` dönüyor.
  static String userRatingSummary(String userId) =>
      '${publicProfile(userId)}/rating-summary';

  /// Bir işverenin istatistikleri: açtığı ilan, tamamlanan iş, puan.
  ///
  /// Şirkete değil **kişiye** bağlı; şirket adına açılan ilanlar da ilanı
  /// açan kullanıcının sayısına yazılıyor.
  static String employerStats(String userId) => '/users/$userId/employer-stats';

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
