import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/core/b_shell_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_home_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_posts_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_profile_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_settings_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_info_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_job_detail_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_user_profile_page.dart';
import 'package:koala/business/features/home/presentation/pages/b_notifications_page.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_list_page.dart';
import 'package:koala/business/features/chat/presentation/pages/b_chat_page.dart';
import 'package:koala/business/features/home/models/b_applicant.dart';
import 'package:koala/employee/features/auth/presentation/pages/auth_gate.dart';
import 'package:koala/employee/features/auth/presentation/pages/auth_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/company_informations_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/creating_password_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/onboarding_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/register_type_page.dart';
import 'package:koala/employee/features/home/presentation/pages/explore_pages/explore_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/jobs_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/review_page.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_list_page.dart';
import 'package:koala/employee/features/chat/presentation/pages/chat_page.dart';
import 'package:koala/employee/features/chat/models/chat.dart';
import 'package:koala/employee/features/profile/presentation/pages/profile_page.dart';
import 'package:koala/employee/features/home/presentation/pages/shell_page.dart';
import 'package:koala/employee/features/company_detail/presentation/pages/company_detail_page.dart';
import 'package:koala/employee/features/company_detail/models/company.dart';
import 'package:koala/employee/features/settings/presentation/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koala/employee/features/auth/presentation/pages/login_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/register_page.dart';
import 'package:koala/employee/features/auth/presentation/pages/email_verification_pending_page.dart';
import 'package:koala/employee/features/jobs/presentation/pages/apply_page.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/settings/presentation/pages/account_info_page.dart';
import 'package:koala/employee/features/profile/models/user.dart';
import 'package:koala/product/network/session_manager.dart';

class RouterManager {
  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(SessionManager.isLoggedInKey) ?? false;
  }

  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(SessionManager.userTypeKey);
  }

  /// Yönlendirme kararını veren saf fonksiyon.
  ///
  /// `SharedPreferences`'tan okuma [redirect] içinde kalıyor, karar mantığı
  /// burada: girdileri parametre olduğu için testten doğrudan çağrılabiliyor.
  /// `null` dönmesi "olduğun yerde kal" demek.
  @visibleForTesting
  static String? resolveRedirect({
    required bool loggedIn,
    required String? userType,
    required String location,
  }) {
    final authRoutes = ['/auth', '/authgate', '/onboarding'];
    final isAuthRoute = authRoutes.any((route) => location.startsWith(route));

    // Giriş yapmamışsa auth'a yönlendir
    if (!loggedIn && !isAuthRoute) {
      return '/authgate';
    }

    // Giriş yapmışsa ve auth sayfasındaysa kullanıcı tipine göre yönlendir
    if (loggedIn && isAuthRoute) {
      if (userType == 'business') {
        return '/business/home';
      } else {
        return '/explore';
      }
    }

    // Business kullanıcısı employee sayfalarına erişmeye çalışırsa
    final employeeRoutes = ['/explore', '/jobs', '/chat', '/profile'];
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

  static final GoRouter router = GoRouter(
    initialLocation: '/explore',
    redirect: (context, state) async {
      return resolveRedirect(
        loggedIn: await isUserLoggedIn(),
        userType: await getUserType(),
        location: state.matchedLocation,
      );
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthPage(),
        routes: [
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: 'register-type',
            builder: (context, state) => const RegisterTypePage(),
            routes: [
              GoRoute(
                path: 'register',
                builder: (context, state) => RegisterPage(
                  isBusiness: state.uri.queryParameters['isBusiness'] == 'true',
                ),
                routes: [
                  GoRoute(
                    path: 'email-verification-pending',
                    builder: (context, state) => EmailVerificationPendingPage(
                      isBusiness:
                          state.uri.queryParameters['isBusiness'] == 'true',
                      email: state.uri.queryParameters['email'],
                    ),
                  ),
                  GoRoute(
                    path: 'creating-password',
                    builder: (context, state) => CreatingPasswordPage(
                      token: state.uri.queryParameters['token'],
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
        path: '/company-informations',
        builder: (context, state) => const CompanyInformationsPage(),
      ),

      GoRoute(path: '/authgate', builder: (context, state) => const AuthGate()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      GoRoute(
        path: '/chat-detail',
        builder: (context, state) {
          final chatData = state.extra as Chat;
          return ChatPage(chat: chatData);
        },
      ),

      GoRoute(
        path: '/company-detail',
        builder: (context, state) {
          final companyData = state.extra as Company;
          return CompanyDetailPage(company: companyData);
        },
      ),

      GoRoute(
        path: '/review',
        builder: (context, state) {
          final job = state.extra as MyJob;
          return ReviewPage(job: job);
        },
      ),

      GoRoute(
        path: '/apply',
        builder: (context, state) {
          final job = state.extra as Job;
          return ApplyPage(job: job);
        },
      ),

      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),

      GoRoute(
        path: '/account-info',
        builder: (context, state) {
          final user = state.extra as User;
          return AccountInfoPage(user: user);
        },
      ),

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
        path: '/business/create',
        builder: (context, state) => const BCreatePage(),
      ),

      GoRoute(
        path: '/business/settings',
        builder: (context, state) => const BSettingsPage(),
      ),

      GoRoute(
        path: '/business/company-info',
        builder: (context, state) => const BCompanyInfoPage(),
      ),

      GoRoute(
        path: '/business/job-detail',
        builder: (context, state) {
          final jobId = state.extra as String;
          return BJobDetailPage(jobId: jobId);
        },
      ),

      GoRoute(
        path: '/business/user-profile',
        builder: (context, state) {
          final applicant = state.extra as BApplicant;
          return BUserProfilePage(applicant: applicant);
        },
      ),

      GoRoute(
        path: '/business/notifications',
        builder: (context, state) => const BNotificationsPage(),
      ),

      GoRoute(
        path: '/business/chat-detail',
        builder: (context, state) {
          final chat = state.extra as Chat;
          return BChatPage(chat: chat);
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
            path: '/profile',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ProfilePage()),
          ),
        ],
      ),
    ],
  );
}
