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

  /// Oturum sahibinin haftalık müsaitlik şablonu. `PUT` bu şablonu toptan
  /// değiştirir; eksik gönderilen bir gün sunucuda silinir.
  static const String currentUserAvailability = '/users/me/availability';

  /// Tarihe özel çalışabilir / çalışamaz istisnaları.
  static const String currentUserAvailabilityExceptions =
      '$currentUserAvailability/exceptions';

  static String currentUserAvailabilityException(String exceptionId) =>
      '$currentUserAvailabilityExceptions/$exceptionId';

  /// Kimlik doğrulama. Ad, soyad, doğum tarihi, TC kimlik ve belge numarası
  /// gönderiliyor; sunucu NVİ'ye soruyor.
  ///
  /// İlana başvurabilmenin ilk şartı bu — doğrulanmamış kullanıcının
  /// başvurusu `APPLICANT_IDENTITY_NOT_VERIFIED` ile reddediliyor.
  static const String currentUserIdentityVerification =
      '/users/me/identity-verification';

  /// Çipe imzalatılacak tek kullanımlık sayı.
  ///
  /// **Kart okunmadan önce** alınmalı: imzalanacak şey bu. `sod` ve `dg1`
  /// bir kart için sabit olduğundan, tekrar gönderimi engelleyen tek şey
  /// bu sayının çipe imzalatılması.
  ///
  /// Sunucu 8 bayt üretip base64 döndürüyor; **tek kullanımlık** ve
  /// **10 dakika** geçerli (`IdentityChallengeManager`).
  static const String currentUserIdentityChallenge =
      '$currentUserIdentityVerification/challenge';

  /// Fotoğraflı kimlik incelemesi.
  ///
  /// `POST` multipart: `identity` JSON parçası (ad, soyad, doğum tarihi,
  /// TCKN, seri no) ve dört dosya parçası `selfie`, `front`, `back`,
  /// `together`. Personel kuyruğuna düşer; kimlik **onaydan sonra**
  /// damgalanır, yanıt hemen `identityVerified` yapmaz. Tek dosya 10 MiB,
  /// toplam gövde 42 MB (`413`); bekleyen inceleme varken ikinci yükleme
  /// `IDENTITY_DOCUMENTS_ALREADY_PENDING` (`400`).
  ///
  /// `GET`: oturum sahibinin son incelemesi; hiç yükleme yoksa `404`
  /// `IDENTITY_DOCUMENTS_NOT_FOUND`.
  static const String currentUserIdentityDocuments =
      '/users/me/identity-documents';

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

  /// Tek oturum: `GET` ayrıntı (IP, konum, giriş geçmişi — koala-backend#306,
  /// eski sunucuda `404`), `DELETE` kapatma.
  static String currentUserSession(String sessionId) =>
      '$currentUserSessions/$sessionId';

  /// Kullanıcının bir cihazı. `PATCH {name}` cihaza özel ad veriyor; ad
  /// oturum listesinde ve ayrıntısında `deviceName` olarak dönüyor.
  static String currentUserDevice(String deviceId) =>
      '/users/me/devices/$deviceId';

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

  /// Kategori × kanal bildirim tercihleri. `GET` çözümlenmiş tabloyu
  /// döndürüyor (satırı olmayan kombinasyon kategorinin varsayılanına
  /// düşüyor); `PUT` yalnız gövdedeki kombinasyonlara dokunuyor ve güncel
  /// tabloyu geri veriyor.
  static const String currentUserNotificationPreferences =
      '/users/me/notification-preferences';

  /// Bu cihazın FCM/APNs token'ı. Oturum ister; `publicPaths`'e girmez.
  ///
  /// Kaynak #29 bitene kadar boş olabilir. Yaşam döngüsü yine de bu ucu
  /// kullanır: token gelince yazar, çıkışta siler.
  static const String currentUserPushToken = '/users/me/devices/push-token';

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

  /// Bir ilanın atamaları, sayfalı (koala-backend#282).
  ///
  /// Yalnızca ilan sahibi ya da şirket ilanının güncel yetkilisi okuyabiliyor;
  /// başkası ve olmayan ilan aynı `404 JOB_NOT_FOUND` yanıtını alıyor. Bu
  /// ucu tanımayan eski sunucu `404 ENDPOINT_NOT_FOUND` döndürüyor; işveren
  /// servisi o durumda [myAssignments] taramasına düşüyor.
  static String assignmentsOfJob(String jobId) => '$jobs/$jobId/assignments';

  /// İlanın ulaşım planı (koala-backend#297, 0.9.28). `GET` işveren
  /// görünümü (plaka, şoför, tam adres, `seatsTaken`); `PUT` planı bütünüyle
  /// yazar. Yalnız ilan sahibi ya da şirket yetkilisi; başkası ve planı
  /// olmayan ilan `404`.
  static String jobTransportPlan(String jobId) => '$jobs/$jobId/transport-plan';

  /// Oturum açmış kullanıcının başvuruları.
  static const String myApplications = '/users/me/applications';

  /// Kabul edilmiş başvuruların dönüştüğü işler.
  static const String myAssignments = '/users/me/assignments';

  /// Oturum sahibi iş arayana yapılan ödeme çıkışları. Düz liste döner.
  static const String currentUserPayouts = '/users/me/payouts';

  /// Kaydedilen ilanlar.
  static const String savedJobs = '/users/me/saved-jobs';

  /// Tek bir ilanı kaydetme / kaydı kaldırma.
  static String savedJob(String jobId) => '$savedJobs/$jobId';

  /// İş alarmında en az bir ölçüt zorunludur; ilçe tek başına ölçüt sayılmaz.
  /// İl ve ilçe adları sunucuda metin olarak eşleştiği için referans
  /// listesinden seçilir. Kullanıcı başına en fazla 10 alarm vardır.
  static const String currentUserJobAlerts = '/users/me/job-alerts';

  static String currentUserJobAlert(String alertId) =>
      '$currentUserJobAlerts/$alertId';

  /// İşverenin ilan şablonları.
  ///
  /// Şablon formdan değil, **var olan bir ilandan** çıkarılıyor: `POST`
  /// gövdesi yalnızca `templateName` ve `jobId` taşıyor, alanları sunucu
  /// ilandan kopyalıyor. İlanın sahibi ya da şirketinin yetkilisi olmayan
  /// biri şablon çıkaramıyor; reddi `404`.
  ///
  /// **Adres, tarih ve durum kopyalanmıyor** — aynı ilan bir sonraki hafta
  /// başka güne, çoğu zaman başka adrese açılıyor. Liste sayfalı değil, düz
  /// bir dizi dönüyor ve kullanıcı bazlı; aynı şirketin başka yetkilisinin
  /// şablonları görünmüyor.
  static const String currentUserJobTemplates = '/users/me/job-templates';

  static String currentUserJobTemplate(String templateId) =>
      '$currentUserJobTemplates/$templateId';

  /// İşverenin yetenek havuzu. Sayfalı; sıralama yalnızca `createdAt`.
  ///
  /// Havuz işveren **kullanıcı** bazlıdır, şirket bazlı değil. `PUT`
  /// upsert'tir: aynı işçiyi ikinci kez eklemek yeni satır açmaz, var olan
  /// kaydın notunu günceller. **Gövdesiz `PUT` var olan notu siler.**
  /// `DELETE` havuzda olmayan biri için sessizce geçer, `404` atmaz.
  static const String currentUserTalentPool = '/users/me/talent-pool';

  static String currentUserTalentPoolEntry(String workerId) =>
      '$currentUserTalentPool/$workerId';

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

  static String assignmentPaymentSession(String assignmentId) =>
      '${jobAssignment(assignmentId)}/payment-session';

  /// İşe alınan çalışanın sigorta bildirimi için kimlik bilgileri
  /// (koala-backend#312, 0.9.27). Yalnız ilan sahibi / şirket yetkilisi,
  /// atama `CONFIRMED|IN_PROGRESS|COMPLETED`; her okuma sunucuda kayda
  /// geçiyor ve çalışana bildiriliyor.
  static String assignmentWorkerIdentity(String assignmentId) =>
      '${jobAssignment(assignmentId)}/worker-identity';

  /// Atamanın bütün ödeme denemeleri. Düz liste döner.
  static String assignmentPayments(String assignmentId) =>
      '${jobAssignment(assignmentId)}/payments';

  /// İlan yayımlanmadan önce backend fiyat snapshot'ını önizler.
  static const String paymentQuotes = '/payment-quotes';

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

  /// Atamanın ulaşım görünümü (koala-backend#297, 0.9.28): ilanın
  /// servisleri ve durakları tam adresle, bu atamanın koltukları. İşçi
  /// görünümünde plaka/şoför yalnız koltuk seçilen serviste dolu. Taraf
  /// olmayan `404`.
  static String assignmentTransport(String assignmentId) =>
      '${jobAssignment(assignmentId)}/transport';

  /// Koltuk seçimi (`PUT {shuttleId, stopId}`). Yön servisten türer, o
  /// yöndeki önceki seçimin yerine geçer. Dolu servis `409`
  /// `TRANSPORT_SHUTTLE_FULL`; aktif olmayan atama `409`.
  static String assignmentTransportSeat(String assignmentId) =>
      '${assignmentTransport(assignmentId)}/seat';

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

  /// İşverenin ilanlar arası başvuru gelen kutusu (koala-backend#233).
  ///
  /// Sahibi olunan bireysel ilanlar ile yetkilisi olunan şirketlerin ilanlarına
  /// gelen başvurular, sayfalı. `GET /users/me/applications` **gönderilen**
  /// başvurular; bu ad onunla karışmasın diye ayrı. Süzgeçler `status`,
  /// `jobId`, `companyId`; kapsam dışı kimlik hata değil boş sayfa. Sıralama
  /// gönderilmezse bekleyenler (`APPLIED`) önde gelir.
  static const String receivedApplications = '/users/me/received-applications';

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

  /// Başvuranın kendi başvurusunu geri çekmesi.
  ///
  /// Silme değil — kayıt duruyor, durumu `WITHDRAWN` oluyor ve işverenin
  /// listesinde görünmeye devam ediyor. Yalnızca `APPLIED` durumundan
  /// geçilebiliyor; başkasının başvurusu `404` (varlığı sızmasın diye `403`
  /// değil).
  static String withdrawApplication(String applicationId) =>
      '/job-applications/$applicationId/withdraw';

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

  /// Şirketin galerisi: `GET` herkese açık, `POST` ve `PUT` yalnızca
  /// şirketin `ADMIN` yetkilisine.
  ///
  /// Okumak için gerekmiyor — şirket detayı görselleri zaten gövdesinde
  /// döndürüyor. Yazma tarafında üç kural var:
  ///
  /// - `POST` multipart ve parçanın adı **`image`**; JSON parçası yok, yanıt
  ///   `201` ve galerinin tamamı.
  /// - `PUT` galeriyi **toptan değiştiriyor**: gövdedeki listede olmayan
  ///   görsel galeriden düşüyor, yani sıralama ya da kapak değişikliğinde
  ///   galerinin tamamı gönderilmeli.
  /// - Galeri en fazla **10 görsel** taşıyor; aşılırsa `409`.
  ///
  /// Dört uç da galerinin son hâlini döndürüyor, ikinci bir okuma gereksiz.
  static String companyImages(String companyId) =>
      '${company(companyId)}/images';

  /// Galerideki tek bir görsel: `DELETE` ile galeriden düşürülüyor.
  ///
  /// [imageId] galeri satırının değil **görselin** kimliği; listede dönen
  /// `GalleryImageDto.id` doğrudan buraya konuyor.
  static String companyImage(String companyId, String imageId) =>
      '${companyImages(companyId)}/$imageId';

  /// İlan galerisi. `GET` herkese açık; yazma uçları yalnız ilanı
  /// düzenleyebilen işverene açıktır. Dört yöntem de galerinin tamamını
  /// döndürür ve `PUT` gövdede olmayan ilişkileri kaldırır.
  static String jobImages(String jobId) => '${job(jobId)}/images';

  /// İlan galerisindeki medya ilişkisini medya kimliğiyle kaldırır.
  static String jobImage(String jobId, String imageId) =>
      '${jobImages(jobId)}/$imageId';

  /// Şirketin yetkilileri. `GET` şirketin yetkilisine açık.
  ///
  /// `DELETE` [companyContact] üzerinden; son `ADMIN` çıkarılamaz (`409`
  /// `COMPANY_LAST_ADMIN_CANNOT_BE_REMOVED`).
  static String companyContacts(String companyId) =>
      '${company(companyId)}/contacts';

  /// Tek bir yetkiliyi çıkarma. [userId] yetkili kaydının değil
  /// **kullanıcının** kimliği.
  static String companyContact(String companyId, String userId) =>
      '${companyContacts(companyId)}/$userId';

  /// Şirkete yetkili daveti gönderme (`POST`) ve şirketin davetlerini
  /// listeleme (`GET`). İkisi de şirketin `ADMIN` yetkilisine açık;
  /// diğer herkes `404` `USER_NOT_ASSOCIATED_WITH_COMPANY` alır.
  static String companyContactInvitations(String companyId) =>
      '${company(companyId)}/contact-invitations';

  /// Davet detayı (`GET`) ve cevap (`POST { accepted }`).
  ///
  /// Okuma: davetli, davet eden, şirket ADMIN'i. Cevap: yalnız davetli.
  /// Diğer herkes `404` `COMPANY_CONTACT_INVITATION_NOT_FOUND` alır —
  /// "var ama senin değil" ile "yok" ayrımı yok.
  static String contactInvitation(String invitationId) =>
      '/contact-invitations/$invitationId';

  /// Şirket logosu: `PUT` ile değiştiriliyor, `DELETE` ile kaldırılıyor.
  /// Yalnızca şirketin `ADMIN` yetkilisi çağırabiliyor.
  static String companyLogo(String companyId) => '${company(companyId)}/logo';

  // ------------------------------------------------------------- Kullanıcı

  /// Bir kullanıcının herkese açık profili.
  ///
  /// Tam adres dönmüyor, yalnızca il ve ilçe. `cvUrl` yalnızca kişinin
  /// kendisine ya da o kişinin başvurduğu bir ilanın işverenine doluyor.
  static String publicProfile(String userId) => '/users/$userId';

  /// Bir kullanıcının herkese açık haftalık müsaitliği ve yaklaşan tarih
  /// istisnaları.
  static String userAvailability(String userId) =>
      '${publicProfile(userId)}/availability';

  /// Bir kullanıcı hakkında yazılmış değerlendirmeler. Sayfalı ve herkese
  /// açık.
  static String userReviews(String userId) =>
      '${publicProfile(userId)}/reviews';

  /// Bir kullanıcının puan özeti: ortalama ve değerlendirme sayısı.
  ///
  /// Hiç değerlendirilmemiş kullanıcı için `data: null` dönüyor.
  static String userRatingSummary(String userId) =>
      '${publicProfile(userId)}/rating-summary';

  /// Bir kullanıcının kazandığı rozetler. Düz liste, herkese açık; kazanılan
  /// rozet geri alınmıyor.
  static String userBadges(String userId) => '${publicProfile(userId)}/badges';

  /// Bir işverenin istatistikleri: açtığı ilan, tamamlanan iş, puan.
  ///
  /// Şirkete değil **kişiye** bağlı; şirket adına açılan ilanlar da ilanı
  /// açan kullanıcının sayısına yazılıyor.
  static String employerStats(String userId) => '/users/$userId/employer-stats';

  // ---------------------------------------------------------------- Sohbet

  static const String conversations = '/conversations';

  /// Bir ilan üzerinden sohbet açar. Sohbet daima ilana bağlı.
  static String jobConversation(String jobId) => '$jobs/$jobId/conversation';

  /// Tek bir sohbet; bildirimden gelirken listeyi çekip aramak yerine.
  static String conversation(String conversationId) =>
      '$conversations/$conversationId';

  /// Sohbetin mesajları. `after=<messageId>` sorgusu yalnız o mesajdan
  /// sonrakileri artan sırada verir; o kipte `sort` gönderilmez.
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

  // -------------------------------------------------------------- Adres arama

  static const String addressSearchSessions =
      '/locations/address-search-sessions';

  static String addressSuggestions(String sessionId) =>
      '$addressSearchSessions/$sessionId/suggestions';

  static String resolveAddressCandidate(String sessionId, String candidateId) =>
      '$addressSearchSessions/$sessionId/candidates/$candidateId/resolve';

  static const String reverseAddressCandidate =
      '/locations/address-candidates/reverse';

  // ------------------------------------------------------------------ Şikayet

  /// Kullanıcı ya da içerik şikayeti açma. Gövde dört hedef alanından
  /// (`reportedUserId`, `jobId`, `messageId`, `imageId`) en az birini
  /// taşımak zorunda; kendini şikayet etmek `400`.
  static const String reports = '/reports';

  /// Oturum sahibinin açtığı şikayetler. Sayfalı, varsayılan `size=20`.
  ///
  /// Moderasyonun gördüğü `/admin/reports` uygulamaya kapalı.
  static const String myReports = '$reports/me';

  // ---------------------------------------------------------------- Engelleme

  /// Oturum sahibinin engellediği kullanıcılar. **Sayfalı değil**; düz bir
  /// liste dönüyor.
  static const String userBlocks = '/users/me/blocks';

  /// Tek bir kullanıcıyı engelleme (`POST`) ve engeli kaldırma (`DELETE`).
  ///
  /// `POST` gövdeyi zorunlu tutuyor (`@RequestBody @Valid`): gerekçe boş olsa
  /// bile en azından `{}` gönderilmeli. İkisi de idempotent — aynı kişiyi
  /// yeniden engellemek ya da engellenmemiş birinin engelini kaldırmak hata
  /// üretmiyor.
  static String userBlock(String userId) => '$userBlocks/$userId';

  // ------------------------------------------------------------- Doğrulamalar

  /// E-posta ya da telefon değişikliğinin 6 haneli kodunu onaylar.
  ///
  /// Kayıt `PATCH /users/me` yanıtındaki `pendingVerifications` içinden
  /// geliyor. Kodun ömrü 15 dakika; onaylanana kadar yeni değer
  /// uygulanmıyor.
  ///
  /// **Tekrar gönderme ucu yok**: aynı yeni değerle `PATCH /users/me`
  /// yeniden çağrıldığında sunucu doğrulanmamış eski kaydı silip yeni bir
  /// kod üretiyor.
  static String verificationConfirm(String verificationId) =>
      '/verifications/$verificationId/confirm';

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
