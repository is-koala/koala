import 'package:flutter/material.dart';
import 'package:koala/business/features/home/presentation/providers/b_page_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';
import 'package:koala/employee/features/home/presentation/providers/search_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/apply_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/saved_jobs_provider.dart';
import 'package:koala/employee/features/jobs/presentation/providers/review_provider.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/product/theme/theme_provider.dart';
import 'package:koala/product/app.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PageProvider()),
        ChangeNotifierProvider(create: (_) => SavedJobsProvider()),
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(create: (_) => ApplyProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()),
        ChangeNotifierProvider(create: (_) => BPageProvider()),
        ChangeNotifierProvider(create: (_) => BJobsProvider()),
      ],
      child: App(),
    ),
  );
}
