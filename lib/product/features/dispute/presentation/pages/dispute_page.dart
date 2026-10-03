import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/dispute/models/dispute_case.dart';
import 'package:koala/product/features/dispute/models/dispute_evidence.dart';
import 'package:koala/product/features/dispute/models/evidence_file.dart';
import 'package:koala/product/features/dispute/presentation/providers/dispute_provider.dart';
import 'package:koala/product/features/dispute/presentation/widgets/dispute_card.dart';
import 'package:koala/product/features/dispute/services/dispute_evidence_service.dart';
import 'package:koala/product/features/dispute/services/evidence_picker.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/option_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

part 'dispute_pagemodel.dart';

/// Bir atamanın uyuşmazlıkları ve kanıtları (is-koala/koala#215).
///
/// Çalışan da işveren de aynı ekranı açıyor (`DisputeRoutes`): atamanın
/// uyuşmazlıkları en yeni önde; her biri durumu, gerekçesi, varsa sonucu ve
/// **kanıtlarıyla**. Açık uyuşmazlığa kamera / galeri / PDF ile dosya
/// eklenebiliyor, mevcut dosyalar indirilebiliyor — sonuçlanmış uyuşmazlığın
/// dosyaları da (karar sonrası okumak meşru).
class DisputePage extends StatefulWidget {
  const DisputePage({
    super.key,
    required this.assignmentId,
    this.assignmentService,
    this.evidenceService,
    this.picker,
    this.openExternalUrl,
    this.clock,
  });

  final String assignmentId;

  /// Testler için: verilmezse üretimdeki tekil servisler / gerçek seçiciler.
  final AssignmentService? assignmentService;
  final DisputeEvidenceService? evidenceService;
  final EvidencePicker? picker;

  /// İndirme adresini açan kapı; verilmezse harici tarayıcı (`url_launcher`).
  /// `BJobDetailPage.openExternalUrl` / `WorkDetailPage.openExternalUrl` ile
  /// aynı kalıp: testler hangi adresin açıldığını ölçüyor.
  final Future<bool> Function(Uri url)? openExternalUrl;

  /// Yükleme anı; adı olmayan dosya buna göre adlanıyor. Testler sabit saat
  /// veriyor.
  final DateTime Function()? clock;

  @override
  State<DisputePage> createState() => _DisputePageState();
}

class _DisputePageState extends DisputePagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Sorun Bildirimi'),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) => _body(context),
      ),
    );
  }

  /// Dört durum ayrı çiziliyor: yükleniyor, hata (mesaj + Tekrar Dene), hiç
  /// uyuşmazlık yok ve liste. Sunucuya ulaşılamadığında "sorun bildirilmemiş"
  /// demek yanlış olurdu.
  Widget _body(BuildContext context) {
    switch (_provider.load) {
      case DisputeLoad.loading:
        return const Center(child: CircularProgressIndicator());
      case DisputeLoad.failed:
        return _refreshable(_errorState(context));
      case DisputeLoad.ready:
        final cases = _provider.cases;
        if (cases.isEmpty) return _refreshable(_emptyState());

        return _refreshable(
          ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppPadding.primaryAll,
            itemCount: cases.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSizes.space),
            itemBuilder: (context, index) {
              final entry = cases[index];
              final upload = _provider.upload;
              return DisputeCard(
                entry: entry,
                upload: upload?.disputeId == entry.dispute.id ? upload : null,
                downloadingId: _provider.downloadingId,
                onAttach: () => _attach(entry),
                onDownload: _download,
                onRetryEvidence: () =>
                    _provider.reloadEvidence(entry.dispute.id),
              );
            },
          ),
        );
    }
  }

  Widget _refreshable(Widget child) {
    return RefreshIndicator(onRefresh: _onRefresh, child: child);
  }

  Widget _emptyState() {
    return const EmptyState(
      icon: AppIcons.shield,
      title: 'Bildirilmiş bir sorun yok',
      description:
          'Bu iş için henüz bir uyuşmazlık açılmamış. Açıldığında kanıtlarıyla '
          'birlikte burada görünür.',
    );
  }

  Widget _errorState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppPadding.primaryAll,
      children: [
        const SizedBox(height: AppSizes.spaceHuge),
        Center(
          child: AppIcon(
            AppIcons.alert,
            size: AppSizes.iconLarge,
            color: context.textTertiary,
          ),
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Text(
          _provider.errorMessage ?? 'Uyuşmazlıklar alınamadı.',
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSizes.spaceMedium),
        Center(
          child: OutlinedButton(
            key: const ValueKey('dispute-retry'),
            onPressed: _provider.start,
            child: const Text('Tekrar Dene'),
          ),
        ),
      ],
    );
  }
}
