import 'dart:async';

import 'package:material_ui/material_ui.dart';
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
        // Nesne okunmadan kuruluyor, cevabı splash alıyor; `main` senkron kalır
        // (#172).
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
        // Çevrimdışı biniş okutmaları (#217); açılışta boşalmalı.
        ChangeNotifierProvider(
          create: (_) => BoardingQueueProvider(),
          lazy: false,
        ),
        // "Az önce gönderdim" belleği; tembel, ilk okunuşta eski disk
        // önbelleğini temizler (#189).
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
