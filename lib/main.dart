import 'dart:async';

import 'package:flutter/material.dart';
import 'package:koala/product/network/api_config.dart';
import 'package:koala/business/features/home/presentation/providers/b_page_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/job_search_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/search_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/boarding_queue_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/settings/presentation/providers/identity_review_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_job_templates_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/product/providers/notification_provider.dart';
import 'package:koala/product/services/maps_availability.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/app.dart';
import 'package:provider/provider.dart';

void main() {
  ApiConfig.validateBuildConfiguration();

  runApp(
    MultiProvider(
      providers: [
        // Harita anahtarı derlemede var mı: nesne burada okunmadan kuruluyor,
        // cevabı açılış ekranı alıyor (`SplashPage._initialize`) — `main`
        // senkron kalır. Kapalıysa harita ekranları yer tutucu gösterir
        // (is-koala/koala#172).
        ChangeNotifierProvider(create: (_) => MapsAvailability()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => IdentityReviewProvider()),
        ChangeNotifierProvider(create: (_) => AvailabilityProvider()),
        ChangeNotifierProvider(create: (_) => JobCategoryProvider()),
        ChangeNotifierProvider(create: (_) => JobSearchProvider()),
        ChangeNotifierProvider(create: (_) => PageProvider()),
        ChangeNotifierProvider(create: (_) => SavedJobsProvider()),
        ChangeNotifierProvider(create: (_) => JobAlertsProvider()),
        ChangeNotifierProvider(
          create: (_) => TimesheetQueueProvider(),
          lazy: false,
        ),
        // Çevrimdışı servis biniş okutmaları (is-koala/koala#217): mesai
        // kuyruğuyla aynı gerekçe, açılışta boşalması gerekiyor.
        ChangeNotifierProvider(
          create: (_) => BoardingQueueProvider(),
          lazy: false,
        ),
        // "Değerlendirdim mi" artık sunucudan (`myReview`); provider yalnız
        // oturumluk "az önce gönderdim" belleği. Provider tembel: önceki
        // sürümlerin disk önbelleği her açılışta provider ilk okunduğunda
        // taranıyor; ilk temizlikten sonra silinecek anahtar kalmadığı için
        // boş bir döngü (is-koala/koala#189).
        ChangeNotifierProvider(
          create: (_) {
            unawaited(ReviewProvider.purgeLegacyCache());
            return ReviewProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ApplyProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => BPageProvider()),
        ChangeNotifierProvider(create: (_) => BJobsProvider()),
        ChangeNotifierProvider(create: (_) => BCompanyProvider()),
        ChangeNotifierProvider(create: (_) => BJobTemplatesProvider()),
        ChangeNotifierProvider(create: (_) => BTalentPoolProvider()),
      ],
      child: App(),
    ),
  );
}
