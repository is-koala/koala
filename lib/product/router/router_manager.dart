import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/core/b_shell_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_home_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_posts_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_profile_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_settings_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_applications_page.dart';
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
import 'package:koala/employee/features/home/presentation/pages/shared_job_page.dart';
import 'package:koala/employee/features/notifications/presentation/pages/notifications_page.dart';
import 'package:koala/employee/features/notifications/presentation/pages/company_invitation_page.dart';
import 'package:koala/employee/features/profile/presentation/pages/followed_companies_page.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_list_page.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_editor_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_stop_editor_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_transport_plan_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_boardings_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_qr_page.dart';
import 'package:koala/business/features/transport/presentation/pages/b_shuttle_scan_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/worker_boarding_qr_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/worker_boarding_scan_page.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/models/transport_plan.dart';
import 'package:koala/product/features/transport/presentation/pages/boarding_link_page.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';
import 'package:koala/employee/features/auth/presentation/pages/splash_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/auth_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/creating_password_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/onboarding_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/register_type_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alerts_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/job_alert_form_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/earnings_page.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/pages/review_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/models/review.dart'
    show ReviewSubject;
import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
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
import 'package:koala/product/features/dispute/dispute_routes.dart';
import 'package:koala/product/models/confirmed_address.dart';
import 'package:koala/product/network/session_manager.dart';
import 'package:koala/product/router/business_routes.dart';
import 'package:koala/product/router/employee_routes.dart';
import 'package:koala/product/widgets/map_first_address_page.dart';

class RouterManager {
  static String _homeFor(String? userType) =>
      userType == SessionManager.businessType ? '/business/home' : '/explore';

  /// Yönlendirme kararını veren saf fonksiyon; `null` "olduğun yerde kal".
  @visibleForTesting
  static String? resolveRedirect({
    required bool loggedIn,
    required String? userType,
    required String location,
    bool initialized = true,
    bool seenOnboarding = true,
  }) {
    // Oturum okunmadı: splash'ta beklenir. "Okunmadı" "giriş yapmamış"
    // değildir; karıştırmak açılışta giriş ekranını bir an gösterir.
    if (!initialized) {
      return location == splashLocation ? null : splashLocation;
    }

    // Splash'ı auth rotalarıyla aynı kümeye koymak giriş yapmamış kullanıcıyı
    // splash'ta kilitler.
    if (location == splashLocation) {
      return loggedIn
          ? _homeFor(userType)
          : (seenOnboarding ? '/auth' : '/onboarding');
    }

    final isAuthRoute =
        location.startsWith('/auth') || location.startsWith('/onboarding');
    final isPublicTokenRoute =
        location == '/reset-password' || location == '/email-verification';

    if (!loggedIn && !isAuthRoute && !isPublicTokenRoute) {
      return seenOnboarding ? '/auth' : '/onboarding';
    }

    if (loggedIn && isAuthRoute) {
      return _homeFor(userType);
    }

    final employeeRoutes = [
      '/explore',
      '/jobs',
      '/job-alerts',
      '/chat',
      EmployeeRoutes.ownProfile,
      '/availability',
      '/earnings',
      EmployeeRoutes.publicProfilePrefix,
      '/shared-job',
      // Biniş ekranları (#217); ortak `/boarding-link` iki listede de yok.
      EmployeeRoutes.boardingPrefix,
    ];
    final isEmployeeRoute = employeeRoutes.any(
      (route) => location.startsWith(route),
    );
    if (loggedIn && userType == 'business' && isEmployeeRoute) {
      return '/business/home';
    }

    final businessRoutes = ['/business'];
    final isBusinessRoute = businessRoutes.any(
      (route) => location.startsWith(route),
    );
    if (loggedIn && userType == 'employee' && isBusinessRoute) {
      return '/explore';
    }

    return null;
  }

  /// Shell dışındaki sayfanın `Page`'i. `builder:` ile go_router
  /// `NoTransitionPage`'e düşüyor; açıkça vermek platform geçişini geri
  /// getiriyor. Navbar sekmeleri kendi `pageBuilder`'larını kullanıyor.
  static Page<void> _page(GoRouterState state, Widget child) =>
      MaterialPage<void>(key: state.pageKey, child: child);

  /// Telefon kamerasıyla okutulan biniş QR'ının indiği sayfa (#217).
  static const String boardingLinkPath = '/boarding-link';

  /// Oturum okunana kadar burada kalınır.
  static const String splashLocation = '/';

  static final GoRouter router = GoRouter(
    initialLocation: splashLocation,
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

      // Şirket bilgileri bilerek `/auth` altında değil: kayıt bitince oturum
      // açık olur ve muhafız auth rotalarından ana sayfaya atardı.
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
          // `MyJob` ya da açılış bağlamını taşıyan `WorkDetailArgs`.
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

      GoRoute(
        path: '/identity-verification',
        pageBuilder: (context, state) {
          final user = state.extra as CurrentUser;
          return _page(state, IdentityVerificationPage(user: user));
        },
      ),

      // Çip okuma: kanıt üretip kapanır; kanıtsız kapanması da meşru.
      GoRoute(
        path: '/identity-chip',
        pageBuilder: (context, state) => _page(state, const IdentityChipPage()),
      ),

      // Fotoğraflı inceleme: dört kare + beyan, sonra personel onayı. `true`
      // ile yalnız onaylanmış incelemede kapanır.
      GoRoute(
        path: '/identity-documents',
        pageBuilder: (context, state) {
          final user = state.extra as CurrentUser;
          return _page(state, IdentityDocumentsPage(user: user));
        },
      ),

      // Harita-öncelikli adres seçici; `context.push<ConfirmedAddress>` ile
      // çağrılır, `extra` önceki adres olabilir.
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

      // Hesap kullanıcıya ait, tarafına değil: iki kabuk aynı rotalara gidiyor.
      ...AccountRoutes.routes(_page),

      // Uyuşmazlık (#215): iki taraf da açıyor, `/business/` öneki yok.
      ...DisputeRoutes.routes(_page),

      ShellRoute(
        builder: (context, state, child) => BShellPage(child: child),
        routes: [
          GoRoute(
            path: '/business/home',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: BHomePage(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          GoRoute(
            path: '/business/posts',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const BPostsPage(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          GoRoute(
            path: '/business/chat',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: const BChatListPage(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 200),
            ),
          ),
          GoRoute(
            path: '/business/profile',
            pageBuilder: (context, state) => CustomTransitionPage(
              key: state.pageKey,
              child: BProfilePage(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) => FadeTransition(opacity: animation, child: child),
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

      // Şirket adresi: harita ekranının `PATCH /companies/{id}`'e bağlı hâli.
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

      // Navbar'ın üstünü kapladığı için shell dışında.
      GoRoute(
        path: BusinessRoutes.applications,
        pageBuilder: (context, state) =>
            _page(state, const BApplicationsPage()),
      ),

      GoRoute(
        path: '/business/job-detail',
        pageBuilder: (context, state) {
          final jobId = state.extra as String;
          return _page(state, BJobDetailPage(jobId: jobId));
        },
      ),

      // Ulaşım planı ve alt sayfaları (#197); kaydedince `pop` ile taslağı
      // döndürür.
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

      // Başkasının profili (#182); navbar'ın üstünü kapladığı için shell
      // dışında.
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

      // Paylaşılan ilan; keşfette detay sheet'ini açar.
      GoRoute(
        path: '/shared-job',
        pageBuilder: (context, state) => _page(
          state,
          SharedJobPage(jobId: state.uri.queryParameters['id'] ?? ''),
        ),
      ),

      // Biniş QR'ı bağlantısı (#217); iki tarafa da açık, yanlış taraf ne
      // yapacağını okur.
      GoRoute(
        path: boardingLinkPath,
        pageBuilder: (context, state) {
          final token = state.uri.queryParameters['t'] ?? '';
          final business =
              SessionManager().userType == SessionManager.businessType;
          return _page(
            state,
            BoardingLinkPage(
              token: token,
              acceptedKind: business
                  ? BoardingTokenKind.worker
                  : BoardingTokenKind.shuttle,
              homeRoute: business ? '/business/home' : '/jobs',
              submit: business
                  ? BShuttleScanPage.submitFromLink
                  : WorkerBoardingScanPage.submitFromLink,
            ),
          );
        },
      ),

      GoRoute(
        path: EmployeeRoutes.boardingQr,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return _page(
            state,
            WorkerBoardingQrPage(
              assignmentId: query['assignmentId'] ?? '',
              direction:
                  ShuttleDirection.fromCode(query['direction']) ??
                  ShuttleDirection.outbound,
            ),
          );
        },
      ),
      GoRoute(
        path: EmployeeRoutes.boardingScan,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return _page(
            state,
            WorkerBoardingScanPage(
              assignmentId: query['assignmentId'],
              direction: ShuttleDirection.fromCode(query['direction']),
              expectedShuttleId: query['shuttleId'],
            ),
          );
        },
      ),
      GoRoute(
        path: BusinessRoutes.shuttleBoardings,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return _page(
            state,
            BShuttleBoardingsPage(
              shuttleId: query['shuttleId'] ?? '',
              shuttleName: query['name'],
            ),
          );
        },
      ),
      GoRoute(
        path: BusinessRoutes.shuttleQr,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return _page(
            state,
            BShuttleQrPage(
              shuttleId: query['shuttleId'] ?? '',
              shuttleName: query['name'],
            ),
          );
        },
      ),
      GoRoute(
        path: BusinessRoutes.shuttleScan,
        pageBuilder: (context, state) {
          final query = state.uri.queryParameters;
          return _page(
            state,
            BShuttleScanPage(
              shuttleId: query['shuttleId'] ?? '',
              shuttleName: query['name'],
            ),
          );
        },
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

      // Çalışan kabuğu. Sekmeleri `ShellPage` kendi `PageView`'ında kuruyor;
      // rotalar yer tutucu çiziyor ve `child` görünmez yerleştiriliyor. Hiç
      // yerleştirilmezse kabuk navigator'ı kurulmaz ve Android geri hareketi
      // null hatasıyla patlar.
      ShellRoute(
        builder: (context, state, child) => ShellPage(child: child),
        routes: [
          for (final path in [
            '/explore',
            '/jobs',
            '/chat',
            EmployeeRoutes.ownProfile,
          ])
            GoRoute(
              path: path,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ShellPage.tabPlaceholder),
            ),
        ],
      ),
    ],
  );
}
