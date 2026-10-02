import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/core/b_shell_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_home_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_posts_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_profile_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_settings_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_gallery_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_address_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_info_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_contacts_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_detail_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_templates_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_talent_pool_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_user_profile_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_notifications_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_payment_result_page.dart';
import 'package:koala/employee/features/notifications/presentation/pages/notifications_page.dart';
import 'package:koala/employee/features/notifications/presentation/pages/company_invitation_page.dart';
import 'package:koala/employee/features/profile/presentation/pages/followed_companies_page.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_list_page.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_editor_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_stop_editor_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_transport_plan_page.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/presentation/pages/splash_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/auth_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/creating_password_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/onboarding_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/register_type_page.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/explore_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/jobs_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alerts_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alert_form_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/earnings_page.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/pages/review_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/models/review.dart'
    show ReviewSubject;
import 'package:koala/employee/features/chat/presentation/pages/chat_list_page.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/profile/presentation/pages/profile_page.dart';
import 'package:koala/employee/features/profile/presentation/pages/public_profile_page.dart';
import 'package:koala/employee/features/profile/presentation/pages/availability_page.dart';
import 'package:koala/employee/features/home/presentation/pages/shell_page.dart';
import 'package:koala/employee/features/company_detail/presentation/pages/company_detail_page.dart';
import 'package:koala/employee/features/settings/presentation/pages/settings_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/login_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/register_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/reset_password_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/email_verification_pending_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/email_verification_link_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/employer_type_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:koala/employee/features/auth/presentation/registration_routes.dart';
import 'package:koala/employee/features/jobs/presentation/pages/apply_page.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_chip_page.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_documents_page.dart';
import 'package:koala/employee/features/settings/presentation/pages/identity_verification_page.dart';
import 'package:koala/product/features/account/account_routes.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';

class RouterManager {
  /// Kullanıcı tipinin ana sayfası.
  static String _homeFor(String? userType) =>
      userType == SessionManager.businessType ? '/business/home' : '/explore';

  /// Yönlendirme kararını veren saf fonksiyon.
  ///
  /// Oturum durumunu okuma [SessionManager]'ın işi; karar mantığı burada:
  /// girdileri parametre olduğu için testten doğrudan çağrılabiliyor.
  /// `null` dönmesi "olduğun yerde kal" demek.
  @visibleForTesting
  static String? resolveRedirect({
    required bool loggedIn,
    required String? userType,
    required String location,
    bool initialized = true,
    bool seenOnboarding = true,
  }) {
    // Oturum durumu daha okunmadı: karar verilemez, splash'ta beklenir.
    // "Okunmadı" ile "giriş yapmamış" aynı şey değil — ikisini karıştırmak
    // açılışta giriş ekranını bir an gösterip sonra ana sayfaya atlamak
    // demek.
    if (!initialized) {
      return location == splashLocation ? null : splashLocation;
    }

    // Splash geçici bir ekran: oturum okunduğuna göre kimse orada kalmaz.
    // Bunu auth rotalarıyla aynı kümeye koymak, giriş yapmamış kullanıcıyı
    // "zaten auth'ta" sayıp splash'ta kilitliyor.
    if (location == splashLocation) {
      return loggedIn
          ? _homeFor(userType)
          : (seenOnboarding ? '/auth' : '/onboarding');
    }

    final isAuthRoute =
        location.startsWith('/auth') || location.startsWith('/onboarding');
    final isPublicTokenRoute =
        location == '/reset-password' || location == '/email-verification';

    // Giriş yapmamışsa: tanıtımı görmemişse önce o, görmüşse giriş ekranı.
    if (!loggedIn && !isAuthRoute && !isPublicTokenRoute) {
      return seenOnboarding ? '/auth' : '/onboarding';
    }

    // Giriş yapmışsa ve auth sayfasındaysa kullanıcı tipine göre yönlendir
    if (loggedIn && isAuthRoute) {
      return _homeFor(userType);
    }

    // Business kullanıcısı employee sayfalarına erişmeye çalışırsa
    final employeeRoutes = [
      '/explore',
      '/jobs',
      '/job-alerts',
      '/chat',
      EmployeeRoutes.ownProfile,
      '/availability',
      '/earnings',
      // Başkasının profilini çalışan açıyor; işverenin karşılığı
      // `BusinessRoutes.userProfile`.
      EmployeeRoutes.publicProfilePrefix,
    ];
    final isEmployeeRoute = employeeRoutes.any(
      (route) => location.startsWith(route),
    );
    if (loggedIn && userType == 'business' && isEmployeeRoute) {
      return '/business/home';
    }

    // Employee kullanıcısı business sayfalarına erişmeye çalışırsa
    final businessRoutes = ['/business'];
    final isBusinessRoute = businessRoutes.any(
      (route) => location.startsWith(route),
    );
    if (loggedIn && userType == 'employee' && isBusinessRoute) {
      return '/explore';
    }

    return null;
  }

  /// Shell dışındaki bir sayfanın `Page`'i.
  ///
  /// Rotalar `builder:` ile bırakıldığında sayfayı go_router uygulama tipine
  /// bakarak kendi seçiyor; bu sürümde o tespit `MaterialApp` altında bile
  /// başarısız olup `NoTransitionPage`'e düşüyor ve shell dışındaki bütün
  /// sayfalar animasyonsuz açılıyordu. Sayfayı burada açıkça vermek
  /// platformun kendi geçişini geri getiriyor: iOS'ta yandan kayma,
  /// Android'de `FadeForwards`.
  ///
  /// Navbar sekmeleri bunu kullanmıyor; onların kendi `pageBuilder`'ları var.
  static Page<void> _page(GoRouterState state, Widget child) =>
      MaterialPage<void>(key: state.pageKey, child: child);

  /// Açılış ekranının yolu. Uygulama buradan başlıyor ve oturum durumu
  /// okunana kadar burada kalıyor.
  static const String splashLocation = '/';

  static final GoRouter router = GoRouter(
    initialLocation: splashLocation,
    // Oturum açılıp kapandığında yönlendirme yeniden değerlendiriliyor;
    // splash'ın okuması bittiğinde kullanıcıyı buradan yola çıkarıyor.
    refreshListenable: SessionManager(),
    redirect: (context, state) {
      final session = SessionManager();
      return resolveRedirect(
        initialized: session.isInitialized,
        loggedIn: session.isLoggedIn,
        userType: session.userType,
        seenOnboarding: session.seenOnboarding,
        location: state.matchedLocation,
      );
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => _page(state, const AuthPage()),
        routes: [
          GoRoute(
            path: 'login',
            pageBuilder: (context, state) => _page(state, const LoginPage()),
          ),
          GoRoute(
            path: 'forgot-password',
            pageBuilder: (context, state) =>
                _page(state, const ForgotPasswordPage()),
          ),
          GoRoute(
            path: 'register-type',
            pageBuilder: (context, state) =>
                _page(state, const RegisterTypePage()),
            routes: [
              GoRoute(
                path: 'register',
                pageBuilder: (context, state) => _page(
                  state,
                  RegisterPage(
                    isBusiness:
                        state.uri.queryParameters['isBusiness'] == 'true',
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'email-verification-pending',
                    pageBuilder: (context, state) => _page(
                      state,
                      EmailVerificationPendingPage(
                        isBusiness:
                            state.uri.queryParameters['isBusiness'] == 'true',
                        email: state.uri.queryParameters['email'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: 'creating-password',
                    pageBuilder: (context, state) => _page(
                      state,
                      CreatingPasswordPage(
                        token: state.uri.queryParameters['token'],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Şirket bilgileri adımı bilerek `/auth` altında değil: kayıt bittiğinde
      // oturum açılmış oluyor ve `redirect` giriş yapmış kullanıcıyı auth
      // rotalarından kendi ana sayfasına atıyor. Üst seviyede durunca adım
      // kayıttan sonra açılabiliyor.
      GoRoute(
        path: '/reset-password',
        pageBuilder: (context, state) => _page(
          state,
          ResetPasswordPage(token: state.uri.queryParameters['token'] ?? ''),
        ),
      ),

      GoRoute(
        path: '/email-verification',
        pageBuilder: (context, state) => _page(
          state,
          EmailVerificationLinkPage(
            token: state.uri.queryParameters['token'] ?? '',
          ),
        ),
      ),

      GoRoute(
        path: RegistrationRoutes.employerType,
        pageBuilder: (context, state) => _page(state, const EmployerTypePage()),
      ),

      GoRoute(
        path: RegistrationRoutes.companyInformations,
        pageBuilder: (context, state) =>
            _page(state, const CompanyInformationsPage()),
      ),

      GoRoute(
        path: splashLocation,
        pageBuilder: (context, state) => _page(state, const SplashPage()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _page(state, const OnboardingPage()),
      ),

      GoRoute(
        path: '/chat-detail',
        pageBuilder: (context, state) {
          final chatData = state.extra as Conversation;
          return _page(state, ChatPage(chat: chatData));
        },
      ),

      GoRoute(
        path: '/company-detail',
        pageBuilder: (context, state) {
          // Ekran şirketi kendisi çekiyor; buraya yalnızca kimlik geçiyor.
          final companyId = state.extra as String;
          return _page(state, CompanyDetailPage(companyId: companyId));
        },
      ),

      GoRoute(
        path: '/review',
        pageBuilder: (context, state) {
          final subject = state.extra as ReviewSubject;
          return _page(state, ReviewPage(subject: subject));
        },
      ),

      GoRoute(
        path: '/apply',
        pageBuilder: (context, state) {
          final job = state.extra as Job;
          return _page(state, ApplyPage(job: job));
        },
      ),

      GoRoute(
        path: '/work-detail',
        pageBuilder: (context, state) {
          // İşlerim satırı ya da Kazançlar satırı `MyJob` veriyor; ulaşım
          // push'u `WorkDetailArgs` ile açılış bağlamını da taşıyor.
          final args = WorkDetailArgs.fromExtra(state.extra);
          return _page(
            state,
            WorkDetailPage(job: args.job, seatDropped: args.seatDropped),
          );
        },
      ),

      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _page(state, const SettingsPage()),
      ),

      GoRoute(
        path: '/job-alerts',
        pageBuilder: (context, state) => _page(state, const JobAlertsPage()),
      ),

      GoRoute(
        path: '/job-alerts/form',
        pageBuilder: (context, state) => _page(
          state,
          JobAlertFormPage(
            alert: state.extra is JobAlert ? state.extra as JobAlert : null,
          ),
        ),
      ),

      GoRoute(
        path: '/availability',
        pageBuilder: (context, state) => _page(state, const AvailabilityPage()),
      ),

      // Kimlik doğrulama başvuru kapısının şartlarından; hesap bilgilerinden
      // ve başvuru ekranından açılıyor. Adres hesap modülünde
      // (`AccountRoutes.address`).
      GoRoute(
        path: '/identity-verification',
        pageBuilder: (context, state) {
          final user = state.extra as CurrentUser;
          return _page(state, IdentityVerificationPage(user: user));
        },
      ),

      // Çip okuma, kimlik ekranından açılıyor ve sonucu ona geri veriyor.
      // Kimliğin kendisini doğrulamıyor: kanıt üretip kapanıyor, kanıtsız
      // kapanması da meşru bir sonuç.
      GoRoute(
        path: '/identity-chip',
        pageBuilder: (context, state) => _page(state, const IdentityChipPage()),
      ),

      // Fotoğraflı inceleme: dört kare + beyan tek istekte, sonra personel
      // onayı. Kimlik ekranı iOS'ta, NFC'siz cihazda ve bir inceleme kaydı
      // varken buraya doğrudan geçiyor; Android'de çip formunun tepesinden
      // ve çip hatalarından da açılıyor. `true` ile yalnız onaylanmış
      // incelemede kapanıyor.
      GoRoute(
        path: '/identity-documents',
        pageBuilder: (context, state) {
          final user = state.extra as CurrentUser;
          return _page(state, IdentityDocumentsPage(user: user));
        },
      ),

      // Harita-öncelikli adres seçici iki uygulamanın da işine yarıyor:
      // işveren ilan ve şirket adresini buradan seçiyor (kullanıcının kendi
      // adresi `/address` üzerinden aynı ekrana `PUT` bağlanmış hâliyle
      // gidiyor).
      // `context.push<ConfirmedAddress>` ile çağrılır; `extra` daha önce
      // onaylanmış adres olabilir, ekran ona açılır.
      GoRoute(
        path: '/pick-address',
        pageBuilder: (context, state) {
          final initial = state.extra;
          return _page(
            state,
            MapFirstAddressPage(
              initialAddress: initial is ConfirmedAddress ? initial : null,
            ),
          );
        },
      ),

      // Hesap modülü: hesap bilgileri, adres, parola, oturumlar, bildirim
      // tercihleri, şikayetler, engellenenler, hesap silme ve doğrulama kodu.
      // Hesap kullanıcıya ait, tarafına değil — iki kabuk da aynı rotalara
      // gidiyor, `/business/` kopyaları yok.
      ...AccountRoutes.routes(_page),

      ShellRoute(
        builder: (context, state, child) => BShellPage(child: child),
        routes: [
          GoRoute(
            path: '/business/home',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: BHomePage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          GoRoute(
            path: '/business/posts',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const BPostsPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          GoRoute(
            path: '/business/chat',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const BChatListPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          GoRoute(
            path: '/business/profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: BProfilePage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) =>
                      FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
        ],
      ),

      GoRoute(
        path: '/payment-result',
        pageBuilder: (context, state) => _page(
          state,
          BPaymentResultPage(
            assignmentId: state.uri.queryParameters['assignmentId'] ?? '',
          ),
        ),
      ),

      GoRoute(
        path: '/business/create',
        pageBuilder: (context, state) => _page(state, const BCreatePage()),
      ),

      GoRoute(
        path: '/business/settings',
        pageBuilder: (context, state) => _page(state, const BSettingsPage()),
      ),

      GoRoute(
        path: '/business/company-info',
        pageBuilder: (context, state) => _page(state, const BCompanyInfoPage()),
      ),

      // Şirket adresi: harita-öncelikli ekranın `PATCH /companies/{id}`'e
      // bağlanmış hâli. Firma bilgilerinin üstüne tam sayfa açılıyor.
      GoRoute(
        path: '/business/company-address',
        pageBuilder: (context, state) =>
            _page(state, const BCompanyAddressPage()),
      ),

      GoRoute(
        path: '/business/company-contacts',
        pageBuilder: (context, state) =>
            _page(state, const BCompanyContactsPage()),
      ),

      GoRoute(
        path: '/business/company-gallery',
        pageBuilder: (context, state) =>
            _page(state, const BCompanyGalleryPage()),
      ),

      GoRoute(
        path: '/business/job-templates',
        pageBuilder: (context, state) =>
            _page(state, const BJobTemplatesPage()),
      ),

      GoRoute(
        path: '/business/talent-pool',
        pageBuilder: (context, state) => _page(state, const BTalentPoolPage()),
      ),

      GoRoute(
        path: '/business/job-detail',
        pageBuilder: (context, state) {
          final jobId = state.extra as String;
          return _page(state, BJobDetailPage(jobId: jobId));
        },
      ),

      // Ulaşım planı düzenleyicisi ve alt sayfaları (is-koala/koala#197).
      // Üçü de üst düzeyde: `/pick-address` gibi navbar'ın üstünü kaplar
      // ve kaydedince `pop` ile taslağı geri verir.
      GoRoute(
        path: BusinessRoutes.transportPlan,
        pageBuilder: (context, state) => _page(
          state,
          BTransportPlanPage(args: state.extra as BTransportPlanArgs),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.transportShuttle,
        pageBuilder: (context, state) => _page(
          state,
          BShuttleEditorPage(args: state.extra as BShuttleEditorArgs),
        ),
      ),
      GoRoute(
        path: BusinessRoutes.transportStop,
        pageBuilder: (context, state) =>
            _page(state, BStopEditorPage(args: state.extra as BStopEditorArgs)),
      ),

      GoRoute(
        path: BusinessRoutes.userProfile,
        pageBuilder: (context, state) {
          return _page(state, BUserProfilePage.fromExtra(state.extra));
        },
      ),

      // Çalışanın başkasının profilini açtığı sayfa (is-koala/koala#182):
      // sohbet katılımcıları ve bireysel işveren kartı. Navbar'ın üstünü
      // kaplıyor, o yüzden shell'in dışında. `extra`: `PublicProfileArgs` ya
      // da kullanıcı kimliği.
      GoRoute(
        path: EmployeeRoutes.publicProfilePattern,
        pageBuilder: (context, state) => _page(
          state,
          PublicProfilePage.fromRoute(
            userId: state.pathParameters['userId']!,
            extra: state.extra,
          ),
        ),
      ),

      GoRoute(
        path: '/followed-companies',
        pageBuilder: (context, state) =>
            _page(state, const FollowedCompaniesPage()),
      ),

      GoRoute(
        path: '/earnings',
        pageBuilder: (context, state) => _page(state, const EarningsPage()),
      ),

      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) =>
            _page(state, const NotificationsPage()),
      ),

      GoRoute(
        path: '/business/notifications',
        pageBuilder: (context, state) =>
            _page(state, const BNotificationsPage()),
      ),

      GoRoute(
        path: '/company-invitation',
        pageBuilder: (context, state) => _page(
          state,
          CompanyInvitationPage(
            invitationId: state.uri.queryParameters['id'] ?? '',
          ),
        ),
      ),

      GoRoute(
        path: '/business/chat-detail',
        pageBuilder: (context, state) {
          final chat = state.extra as Conversation;
          return _page(state, BChatPage(chat: chat));
        },
      ),

      //Employee Main Shell
      ShellRoute(
        builder: (context, state, child) => ShellPage(child: child),
        routes: [
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ExplorePage()),
          ),
          GoRoute(
            path: '/jobs',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const JobsPage()),
          ),
          GoRoute(
            path: '/chat',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ChatListPage()),
          ),
          GoRoute(
            path: EmployeeRoutes.ownProfile,
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ProfilePage()),
          ),
        ],
      ),
    ],
  );
}
