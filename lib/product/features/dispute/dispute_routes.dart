import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/features/dispute/presentation/pages/dispute_page.dart';

/// Uyuşmazlık ekranının rotası (#215). İki taraf da açıyor, o yüzden
/// `/business/` öneki yok. Atama kimliği yol parametresi ve tek kaynak; `extra`
/// yok.
class DisputeRoutes {
  const DisputeRoutes._();

  static const String pattern = '/assignment-dispute/:assignmentId';

  static String location(String assignmentId) =>
      '/assignment-dispute/${Uri.encodeComponent(assignmentId)}';

  /// [page] `RouterManager._page`; vermezsek sayfa animasyonsuz açılır.
  static List<GoRoute> routes(
    Page<void> Function(GoRouterState state, Widget child) page,
  ) {
    return [
      GoRoute(
        path: pattern,
        pageBuilder: (context, state) => page(
          state,
          DisputePage(assignmentId: state.pathParameters['assignmentId']!),
        ),
      ),
    ];
  }
}
