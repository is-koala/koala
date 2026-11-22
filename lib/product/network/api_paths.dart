/// Backend uç noktalarının yolları. Tek yerde duruyorlar ki [AuthInterceptor]
/// "bu yol token ister mi" sorusunu string kopyalamadan yanıtlayabilsin.
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

  /// Haftalık müsaitlik şablonu. `PUT` toptan değiştirir; gönderilmeyen gün
  /// sunucuda silinir.
  static const String currentUserAvailability = '/users/me/availability';

  static const String currentUserAvailabilityExceptions =
      '$currentUserAvailability/exceptions';

  static String currentUserAvailabilityException(String exceptionId) =>
      '$currentUserAvailabilityExceptions/$exceptionId';

  /// Kimlik doğrulama (sunucu NVİ'ye soruyor). Doğrulanmamış kullanıcının
  /// başvurusu `APPLICANT_IDENTITY_NOT_VERIFIED` ile reddedilir.
  static const String currentUserIdentityVerification =
      '/users/me/identity-verification';

  /// Çipe imzalatılacak tek kullanımlık sayı (8 bayt, base64, 10 dakika).
  /// **Kart okunmadan önce** alınmalı: `sod` ve `dg1` kart için sabit
  /// olduğundan tekrar gönderimi yalnız bu imza engelliyor.
  static const String currentUserIdentityChallenge =
      '$currentUserIdentityVerification/challenge';

  /// Fotoğraflı kimlik incelemesi.
  ///
  /// `POST` multipart: `identity` JSON parçası ve `selfie`, `front`, `back`,
  /// `together` dosyaları (tek dosya 10 MiB, toplam 42 MB). Personel kuyruğuna
  /// düşer; `identityVerified` onaydan sonra gelir. Bekleyen inceleme varken
  /// `IDENTITY_DOCUMENTS_ALREADY_PENDING`.
  ///
  /// `GET`: son inceleme; hiç yükleme yoksa `404 IDENTITY_DOCUMENTS_NOT_FOUND`.
  static const String currentUserIdentityDocuments =
      '/users/me/identity-documents';

  /// Takip edilen şirketler, sayfalı.
  static const String followedCompanies = '/users/me/followed-companies';

  // ----------------------------------------------------------------- Eğitim

  /// Öğrenim kayıtları. Liste `/users/me`'de de geliyor; bu uçlar yazma için.
  static const String currentUserEducations = '/users/me/educations';

  static String currentUserEducation(String educationId) =>
      '$currentUserEducations/$educationId';

  /// Kimlik doğrulama istemeyen üniversite / fakülte / bölüm listeleri.
  static const String universities = '/reference/universities';

  static String universityFaculties(String universityId) =>
      '$universities/$universityId/faculties';

  static String facultyDepartments(String facultyId) =>
      '/reference/faculties/$facultyId/departments';

  // ---------------------------------------------------------------- Oturumlar

  /// Açık oturumlar. `DELETE` isteği atan oturum dışındakileri kapatır.
  static const String currentUserSessions = '/users/me/sessions';

  /// Tek oturum: `GET` ayrıntı (eski sunucuda `404`), `DELETE` kapatma.
  static String currentUserSession(String sessionId) =>
      '$currentUserSessions/$sessionId';

  /// Cihaz. `PATCH {name}` oturum listesindeki `deviceName`'i değiştirir.
  static String currentUserDevice(String deviceId) =>
      '/users/me/devices/$deviceId';

  // ------------------------------------------------------------- Bildirimler

  /// Bildirim akışı, sayfalı; okunmamış sayısı da aynı yanıtta.
  static const String currentUserNotifications = '/users/me/notifications';

  static const String currentUserNotificationsRead =
      '$currentUserNotifications/read';

  /// Zaten okunmuş ya da başkasına ait bildirimde sunucu sessizce geçer.
  static String currentUserNotificationRead(String notificationId) =>
      '$currentUserNotifications/$notificationId/read';

  /// Kategori × kanal tercihleri. `GET` çözümlenmiş tabloyu döndürür; `PUT`
  /// yalnız gövdedeki kombinasyonlara dokunur.
  static const String currentUserNotificationPreferences =
      '/users/me/notification-preferences';

  /// Bu cihazın push token'ı. Oturum ister; token gelince yazılır, çıkışta
  /// silinir.
  static const String currentUserPushToken = '/users/me/devices/push-token';

  // ------------------------------------------------------------------ Deneyim

  /// İş deneyimleri. Liste `/users/me`'de de geliyor; başkasının kaydı `404`.
  static const String currentUserExperiences = '/users/me/experiences';

  static String currentUserExperience(String experienceId) =>
      '$currentUserExperiences/$experienceId';

  // --------------------------------------------------------------------- Jobs

  static const String jobs = '/jobs';

  static String job(String jobId) => '$jobs/$jobId';

  static String jobApplications(String jobId) => '$jobs/$jobId/applications';

  /// İlanın atamaları, sayfalı. Yalnız ilan sahibi ya da şirket yetkilisi;
  /// başkası `404 JOB_NOT_FOUND`. Ucu tanımayan eski sunucu `404
  /// ENDPOINT_NOT_FOUND` döndürür, servis o zaman [myAssignments]'a düşer.
  static String assignmentsOfJob(String jobId) => '$jobs/$jobId/assignments';

  /// İlanın ulaşım planı. `GET` işveren görünümü, `PUT` planı bütünüyle yazar.
  /// Yalnız ilan sahibi ya da şirket yetkilisi; planı yoksa `404`.
  static String jobTransportPlan(String jobId) => '$jobs/$jobId/transport-plan';

  static const String myApplications = '/users/me/applications';

  /// Kabul edilmiş başvuruların dönüştüğü işler.
  static const String myAssignments = '/users/me/assignments';

  static const String currentUserPayouts = '/users/me/payouts';

  static const String savedJobs = '/users/me/saved-jobs';

  static String savedJob(String jobId) => '$savedJobs/$jobId';

  /// İş alarmı: en az bir ölçüt zorunlu (ilçe tek başına sayılmaz), kullanıcı
  /// başına en çok 10. İl/ilçe sunucuda metinle eşleştiği için referans
  /// listesinden seçilir.
  static const String currentUserJobAlerts = '/users/me/job-alerts';

  static String currentUserJobAlert(String alertId) =>
      '$currentUserJobAlerts/$alertId';

  /// İşverenin ilan şablonları, kullanıcı bazlı ve sayfasız.
  ///
  /// Şablon **var olan bir ilandan** çıkarılır: `POST` yalnız `templateName` ve
  /// `jobId` taşır. Adres, tarih ve durum kopyalanmaz.
  static const String currentUserJobTemplates = '/users/me/job-templates';

  static String currentUserJobTemplate(String templateId) =>
      '$currentUserJobTemplates/$templateId';

  /// İşverenin yetenek havuzu (kullanıcı bazlı), sayfalı. `PUT` upsert;
  /// **gövdesiz `PUT` notu siler**. Havuzda olmayan için `DELETE` `404` atmaz.
  static const String currentUserTalentPool = '/users/me/talent-pool';

  static String currentUserTalentPoolEntry(String workerId) =>
      '$currentUserTalentPool/$workerId';

  // ----------------------------------------------------------------- Atama

  static const String jobAssignments = '/job-assignments';

  static String jobAssignment(String assignmentId) =>
      '$jobAssignments/$assignmentId';

  /// Çalışanın atamayı kabul ya da reddetmesi. Atama `PENDING_CONFIRMATION`
  /// dışındaysa `409`.
  static String respondToAssignment(String assignmentId) =>
      '${jobAssignment(assignmentId)}/respond';

  static String assignmentPaymentSession(String assignmentId) =>
      '${jobAssignment(assignmentId)}/payment-session';

  /// Sigorta bildirimi için çalışanın kimlik bilgileri. Yalnız işveren, atama
  /// `CONFIRMED|IN_PROGRESS|COMPLETED`; her okuma kayda geçer ve çalışana
  /// bildirilir.
  static String assignmentWorkerIdentity(String assignmentId) =>
      '${jobAssignment(assignmentId)}/worker-identity';

  static String assignmentPayments(String assignmentId) =>
      '${jobAssignment(assignmentId)}/payments';

  /// Yayımlamadan önce fiyat snapshot'ı önizlemesi.
  static const String paymentQuotes = '/payment-quotes';

  /// Mesai başlatma / bitirme; yalnız işi yapan kişi, konum isteğe bağlı. Para
  /// emanete alınmadan (`HELD_IN_ESCROW`) giriş `409`.
  static String assignmentCheckIn(String assignmentId) =>
      '${jobAssignment(assignmentId)}/check-in';

  static String assignmentCheckOut(String assignmentId) =>
      '${jobAssignment(assignmentId)}/check-out';

  static String assignmentWorkSessions(String assignmentId) =>
      '${jobAssignment(assignmentId)}/work-sessions';

  /// Atamayı iptal etme ve iptal kaydını okuma. Gerekçe zorunlu, atama başına
  /// tek kayıt (ikincisi `409`). Kesinti sunucuda hesaplanır; önceden görmek
  /// için [assignmentCancellationPreview].
  static String cancelAssignment(String assignmentId) =>
      '${jobAssignment(assignmentId)}/cancel';

  static String assignmentCancellation(String assignmentId) =>
      '${jobAssignment(assignmentId)}/cancellation';

  /// İptal etmeden ne kesileceğini döndürür. Uygun değilse hata değil
  /// `cancellableNow: false`.
  static String assignmentCancellationPreview(String assignmentId) =>
      '${jobAssignment(assignmentId)}/cancellation-preview';

  /// Uyuşmazlık açma ve listeleme. Yalnız para emanetteyken ve aynı anda tek
  /// açık uyuşmazlık; ikisi de `409`.
  static String assignmentDisputes(String assignmentId) =>
      '${jobAssignment(assignmentId)}/disputes';

  /// Uyuşmazlık kanıtları: `GET` liste, `POST` tek dosya (`file` parçası).
  /// Yalnız taraflar; sonuçlanmamış uyuşmazlığa en çok 5.
  static String disputeEvidence(String disputeId) =>
      '$disputes/$disputeId/evidence';

  /// `Bearer` ister ve kısa ömürlü imzalı adrese `302` verir.
  static String disputeEvidenceDownload(String disputeId, String evidenceId) =>
      '${disputeEvidence(disputeId)}/$evidenceId/download';

  static const String disputes = '/disputes';

  /// İşi tamamlandı işaretleme; yalnız işveren. `CONFIRMED`/`IN_PROGRESS`
  /// dışında `409`.
  static String completeAssignment(String assignmentId) =>
      '${jobAssignment(assignmentId)}/complete';

  /// Atamanın ulaşım görünümü. Plaka/şoför yalnız koltuk seçilen serviste dolu.
  static String assignmentTransport(String assignmentId) =>
      '${jobAssignment(assignmentId)}/transport';

  /// Koltuk seçimi (`PUT {shuttleId, stopId}`); o yöndeki önceki seçimin yerine
  /// geçer. Dolu servis `409 TRANSPORT_SHUTTLE_FULL`.
  static String assignmentTransportSeat(String assignmentId) =>
      '${assignmentTransport(assignmentId)}/seat';

  /// İşçinin biniş QR'ı: `GET ?direction=OUTBOUND|RETURN`. Koltuk yoksa ya da
  /// biniş kapalıysa `409`.
  static String assignmentTransportQr(String assignmentId) =>
      '${assignmentTransport(assignmentId)}/qr';

  static String shuttle(String shuttleId) => '/shuttles/$shuttleId';

  /// Servisin biniş QR'ı: `GET ?static=false|true`; yalnız işveren.
  static String shuttleQr(String shuttleId) => '${shuttle(shuttleId)}/qr';

  /// QR anahtarını yeniler: basılı olanlar dahil bütün servis ve işçi QR'ları
  /// geçersizleşir.
  static String shuttleQrRotate(String shuttleId) =>
      '${shuttleQr(shuttleId)}/rotate';

  /// `POST`: işçi servis QR'ıyla biner. `GET`: işverenin biniş listesi.
  static String shuttleBoardings(String shuttleId) =>
      '${shuttle(shuttleId)}/boardings';

  /// İşverenin koltuk binişi: işçi QR'ı ya da BOARDED/NO_SHOW işareti.
  static String seatBoardings(String seatAssignmentId) =>
      '/seat-assignments/$seatAssignmentId/boardings';

  /// Değerlendirme yazma; okuması [userReviews]. Taraf başına bir kez, ikincisi
  /// `409`.
  static String assignmentReviews(String assignmentId) =>
      '${jobAssignment(assignmentId)}/reviews';

  // ----------------------------------------------------------------- İşveren

  /// Oturum sahibinin açtığı ilanlar. Şirket ilanları da burada: backend
  /// `creatorId`'ye bakıyor.
  static const String myJobs = '/users/me/jobs';

  /// İşverene gelen başvurular, sayfalı (gönderilenler [myApplications]).
  /// Süzgeçler `status`, `jobId`, `companyId`; kapsam dışı kimlik boş sayfa
  /// döndürür. Sıralama verilmezse `APPLIED` önde.
  static const String receivedApplications = '/users/me/received-applications';

  /// Bireysel ilan açma; şirket ilanı [companyJobs].
  static const String createIndividualJob = myJobs;

  static String companyJobs(String companyId) => '/companies/$companyId/jobs';

  /// Başvuruya kapatma: yeni başvuru gelmez, ilan geçerli kalır.
  static String closeJob(String jobId) => '${job(jobId)}/close';

  /// İptal: ilan geçersiz olur, başvuranlara bildirim gider. Devam eden atama
  /// varken `409`; o zaman atamanın iptal akışı kullanılmalı.
  static String cancelJob(String jobId) => '${job(jobId)}/cancel';

  static String respondToApplication(String applicationId) =>
      '/job-applications/$applicationId/respond';

  /// Başvuruyu geri çekme: kayıt `WITHDRAWN` olarak kalır. Yalnız `APPLIED`
  /// durumundan; başkasının başvurusu varlığı sızmasın diye `404`.
  static String withdrawApplication(String applicationId) =>
      '/job-applications/$applicationId/withdraw';

  // ------------------------------------------------------------------ Şirket

  static const String companies = '/companies';

  /// `GET` detay, `PATCH` güncelleme (yalnız `ADMIN`; üye olmayan `404`).
  static String company(String companyId) => '$companies/$companyId';

  /// Takip (`POST`) / takibi bırakma (`DELETE`). Durum şirket detayındaki
  /// `following` alanında.
  static String companyFollow(String companyId) =>
      '${company(companyId)}/follow';

  /// Şirket galerisi: `GET` herkese açık, yazma yalnız `ADMIN`.
  ///
  /// - `POST` multipart, parça adı **`image`**.
  /// - `PUT` galeriyi **toptan değiştirir**: listede olmayan görsel düşer, yani
  ///   sıra ya da kapak değişince galerinin tamamı gönderilmeli.
  /// - En çok **10 görsel**; aşılırsa `409`.
  ///
  /// Bütün uçlar galerinin son hâlini döndürür.
  static String companyImages(String companyId) =>
      '${company(companyId)}/images';

  /// Galeriden görsel kaldırma. [imageId] galeri satırının değil **görselin**
  /// kimliği (`GalleryImageDto.id`).
  static String companyImage(String companyId, String imageId) =>
      '${companyImages(companyId)}/$imageId';

  /// İlan galerisi. `GET` herkese açık, yazma ilanı düzenleyebilen işverene.
  /// Hepsi galerinin tamamını döndürür; `PUT` gövdede olmayanı kaldırır.
  static String jobImages(String jobId) => '${job(jobId)}/images';

  static String jobImage(String jobId, String imageId) =>
      '${jobImages(jobId)}/$imageId';

  /// Şirket yetkilileri. Son `ADMIN` çıkarılamaz (`409
  /// COMPANY_LAST_ADMIN_CANNOT_BE_REMOVED`).
  static String companyContacts(String companyId) =>
      '${company(companyId)}/contacts';

  /// [userId] yetkili kaydının değil **kullanıcının** kimliği.
  static String companyContact(String companyId, String userId) =>
      '${companyContacts(companyId)}/$userId';

  /// Yetkili daveti gönderme ve listeleme; yalnız `ADMIN`, diğerleri `404
  /// USER_NOT_ASSOCIATED_WITH_COMPANY`.
  static String companyContactInvitations(String companyId) =>
      '${company(companyId)}/contact-invitations';

  /// Davet detayı (`GET`) ve cevap (`POST { accepted }`, yalnız davetli).
  /// Yetkisiz herkes `404`; "senin değil" ile "yok" ayrılmıyor.
  static String contactInvitation(String invitationId) =>
      '/contact-invitations/$invitationId';

  /// Logo: `PUT` değiştirir, `DELETE` kaldırır; yalnız `ADMIN`.
  static String companyLogo(String companyId) => '${company(companyId)}/logo';

  // ------------------------------------------------------------- Kullanıcı

  /// Herkese açık profil: adres yalnız il/ilçe. `cvUrl` yalnız kişinin
  /// kendisine ya da başvurduğu ilanın işverenine dolu.
  static String publicProfile(String userId) => '/users/$userId';

  /// Haftalık müsaitlik ve yaklaşan istisnalar.
  static String userAvailability(String userId) =>
      '${publicProfile(userId)}/availability';

  /// Kullanıcı hakkındaki değerlendirmeler, sayfalı.
  static String userReviews(String userId) =>
      '${publicProfile(userId)}/reviews';

  /// Puan özeti; hiç değerlendirilmemişse `data: null`.
  static String userRatingSummary(String userId) =>
      '${publicProfile(userId)}/rating-summary';

  static String userBadges(String userId) => '${publicProfile(userId)}/badges';

  /// İşveren istatistikleri. Şirkete değil **kişiye** bağlı: şirket adına
  /// açılan ilan da açan kullanıcıya yazılır.
  static String employerStats(String userId) => '/users/$userId/employer-stats';

  // ---------------------------------------------------------------- Sohbet

  static const String conversations = '/conversations';

  /// İlan üzerinden sohbet açar; sohbet hep bir ilana bağlı.
  static String jobConversation(String jobId) => '$jobs/$jobId/conversation';

  /// Tek sohbet; bildirimden açarken listeyi taramamak için.
  static String conversation(String conversationId) =>
      '$conversations/$conversationId';

  /// Mesajlar. `after=<messageId>` o mesajdan sonrakileri artan sırada verir; o
  /// kipte `sort` gönderilmez.
  static String conversationMessages(String conversationId) =>
      '$conversations/$conversationId/messages';

  static String conversationRead(String conversationId) =>
      '$conversations/$conversationId/read';

  static const String presenceLookup = '/presence/lookup';

  // ---------------------------------------------------------- Reference data

  static const String jobCategories = '/reference/job-categories';

  static const String countries = '/reference/countries';

  static String cities(String countryId) => '$countries/$countryId/cities';

  /// İlçeler `/reference/cities/...` altında, [cities] ülke altında.
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

  /// Şikayet açma. `reportedUserId`, `jobId`, `messageId`, `imageId`'den en az
  /// biri zorunlu; kendini şikayet `400`.
  static const String reports = '/reports';

  /// Oturum sahibinin şikayetleri, sayfalı.
  static const String myReports = '$reports/me';

  // ---------------------------------------------------------------- Engelleme

  /// Engellenenler; **sayfalı değil**.
  static const String userBlocks = '/users/me/blocks';

  /// Engelleme (`POST`) / kaldırma (`DELETE`), ikisi de idempotent. `POST`
  /// gövde istiyor: gerekçe yoksa da `{}` gönderilmeli.
  static String userBlock(String userId) => '$userBlocks/$userId';

  // ------------------------------------------------------------- Doğrulamalar

  /// E-posta / telefon değişikliğinin 6 haneli kodunu onaylar (15 dakika).
  /// Kayıt `PATCH /users/me` yanıtındaki `pendingVerifications`'tan gelir.
  ///
  /// **Tekrar gönderme ucu yok**: aynı değerle `PATCH` yeniden çağrılınca
  /// sunucu yeni kod üretir.
  static String verificationConfirm(String verificationId) =>
      '/verifications/$verificationId/confirm';

  // -------------------------------------------------------------------- Legal

  static const String agreements = '/legal/agreements';
  static const String consents = '/legal/consents';
  static const String accountDeletion = '/legal/account-deletion';

  /// Token taşımadan çağrılan uçlar; diğer her isteğe `Authorization`
  /// ekleniyor. [refreshToken] bilerek dışarıda: backend oturumu süresi dolmuş
  /// erişim token'ından okuyor.
  static const Set<String> publicPaths = {
    startRegistration,
    verifyRegistrationToken,
    completeRegistration,
    login,
    forgotPassword,
    resetPassword,
    agreements,
    // İl/ilçe yolları değişken olduğu için kümeye giremiyor; token taşımaları
    // zararsız.
    jobCategories,
    countries,
  };
}
