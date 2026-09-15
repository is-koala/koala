import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/presentation/pages/work_detail_page.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/services/push_work_detail_opener.dart';

import '../../support/fake_api.dart';
import '../../support/work_test_support.dart';

void main() {
  group('PushWorkDetailOpener', () {
    late List<WorkDetailArgs?> navigations;

    setUp(() => navigations = []);

    PushWorkDetailOpener build(FakeApi api) => PushWorkDetailOpener(
      assignmentService: AssignmentService.withClient(api.client),
      navigate: navigations.add,
    );

    test('atamayı okur ve iş detayını bağlamıyla açar', () async {
      final api = FakeApi(handler: (_) => dataResponse(assignmentJson()));

      await build(api).open(assignmentId: 'assignment-1', seatDropped: true);

      expect(api.requests.single.path, '/job-assignments/assignment-1');
      final args = navigations.single!;
      expect(args.job.assignmentId, 'assignment-1');
      expect(args.job.status, MyJobStatus.approved);
      expect(args.seatDropped, isTrue);
    });

    test('atama okunamazsa yalnız İşlerim açılır', () async {
      final api = FakeApi(
        handler: (_) => const FakeApiResponse(
          statusCode: 404,
          body: {
            'success': false,
            'message': 'Atama bulunamadı.',
            'errorCategory': 'RESOURCE_NOT_FOUND',
          },
        ),
      );

      await build(api).open(assignmentId: 'assignment-x', seatDropped: false);

      expect(navigations, [null]);
    });
  });

  group('openWorkDetailOn', () {
    late GoRouter router;

    GoRouter buildRouter() => GoRouter(
      initialLocation: '/explore',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              Scaffold(body: child, bottomNavigationBar: const Text('navbar')),
          routes: [
            GoRoute(
              path: '/explore',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: Text('keşfet')),
            ),
            GoRoute(
              path: PushWorkDetailOpener.jobsRoute,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: Text('işlerim')),
            ),
          ],
        ),
        GoRoute(
          path: PushWorkDetailOpener.detailRoute,
          pageBuilder: (context, state) {
            final args = WorkDetailArgs.fromExtra(state.extra);
            return MaterialPage(
              child: Text(
                'detay: ${args.job.title} '
                '${args.seatDropped ? 'düştü' : 'normal'}',
              ),
            );
          },
        ),
      ],
    );

    Iterable<String> stack() => router
        .routerDelegate
        .currentConfiguration
        .matches
        .map((match) => match.matchedLocation);

    setUp(() {
      router = buildRouter();
      addTearDown(router.dispose);
    });

    testWidgets('İşlerim üstüne iş detayı açılır, geri İşlerim', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final job = MyJob.fromAssignment(Assignment.fromJson(assignmentJson()));
      openWorkDetailOn(router, WorkDetailArgs(job: job, seatDropped: true));
      await tester.pumpAndSettle();

      expect(find.text('detay: Barista düştü'), findsOneWidget);
      expect(stack(), ['/jobs', '/work-detail']);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('işlerim'), findsOneWidget);
      expect(find.text('navbar'), findsOneWidget);
    });

    testWidgets('kayıt yoksa yalnız İşlerim', (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      openWorkDetailOn(router, null);
      await tester.pumpAndSettle();

      expect(find.text('işlerim'), findsOneWidget);
      expect(stack(), ['/jobs']);
    });
  });

  group('WorkDetailArgs.fromExtra', () {
    test('MyJob ve WorkDetailArgs ikisi de kabul', () {
      final job = MyJob.fromAssignment(Assignment.fromJson(assignmentJson()));

      final plain = WorkDetailArgs.fromExtra(job);
      expect(plain.job, same(job));
      expect(plain.seatDropped, isFalse);

      final args = WorkDetailArgs(job: job, seatDropped: true);
      expect(WorkDetailArgs.fromExtra(args), same(args));
    });

    test('başka bir şey eskisi gibi fırlatır', () {
      expect(() => WorkDetailArgs.fromExtra('x'), throwsA(isA<TypeError>()));
    });
  });
}
