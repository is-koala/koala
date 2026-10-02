import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/features/dispute/presentation/pages/dispute_page.dart';

/// Uyuşmazlık ekranının rotası (is-koala/koala#215).
///
/// Ekranı çalışan da işveren de açıyor: kanıt ucu atamanın **tarafı** kimse
/// ona izin veriyor. Yol bu yüzden `/business/` öneki taşımıyor (önek
/// yönlendirme kapısında çalışanı geri çevirir) ve çalışan öneklerinden
/// birine de girmiyor — `AccountRoutes` ile aynı gerekçe.
///
/// **Atama kimliği yol parametresi ve tek doğru kaynak:** sayfa uyuşmazlıkları
/// `GET /job-assignments/{id}/disputes` ile kendisi okuyor; `extra` yok, bu
/// yüzden eksik ya da yanlış bir `extra` sayfayı düşüremez.
class DisputeRoutes {
  const DisputeRoutes._();

  /// Rota deseni; kimlik `:assignmentId`.
  static const String pattern = '/assignment-dispute/:assignmentId';

  /// Bir atamanın uyuşmazlık ekranının konumu.
  static String location(String assignmentId) =>
      '/assignment-dispute/${Uri.encodeComponent(assignmentId)}';

  /// Modülün `GoRoute` listesi; [page] `RouterManager._page` (her rota kendi
  /// `pageBuilder`'ını vermek zorunda, yoksa sayfa animasyonsuz açılır).
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
