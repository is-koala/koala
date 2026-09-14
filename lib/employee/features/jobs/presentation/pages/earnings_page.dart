import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/jobs/models/assignment.dart';
import 'package:koala/employee/features/jobs/models/my_job.dart';
import 'package:koala/employee/features/jobs/models/payout.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/payout_detail_sheet.dart';
import 'package:koala/employee/features/jobs/presentation/widgets/payout_status_badge.dart';
import 'package:koala/employee/features/jobs/services/assignment_service.dart';
import 'package:koala/employee/features/jobs/services/payout_service.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/formatters/turkish_money_formatter.dart';
import 'package:koala/product/formatters/financial_failure_message.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/my_appbar.dart';

part 'earnings_pagemodel.dart';

/// İş arayanın tamamlanan ve işlemdeki ödeme çıkışları.
class EarningsPage extends StatefulWidget {
  const EarningsPage({super.key, this.service, this.assignmentService});

  final PayoutService? service;
  final AssignmentService? assignmentService;

  @override
  State<EarningsPage> createState() => _EarningsPageState();
}

class _EarningsPageState extends EarningsPagemodel {
  /// Satırdaki bekleme halkasının kalınlığı; varsayılan bu boyutta dolu
  /// görünüyor.
  static const double _spinnerStroke = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Kazançlarım'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _errorMessage;
    if (error != null) return _errorState(error);

    if (_payouts.isEmpty) {
      return const EmptyState(
        icon: AppIcons.moneyBag,
        title: 'Henüz bir ödeme almadın.',
        description: 'Tamamlanan işlerinin ödeme çıkışları burada görünecek.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppPadding.primaryAll,
        itemCount: _payouts.length + 1,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.spaceSmall),
        itemBuilder: (context, index) {
          if (index == 0) return _summaryCard();
          return _payoutCard(_payouts[index - 1]);
        },
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(onPressed: _load, child: const Text('Tekrar Dene')),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.payoutSurface,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kazanç Özeti', style: context.textTheme.titleMedium),
          const SizedBox(height: AppSizes.space),
          _summaryRow('Tamamlanan', _totalsFor(const {PayoutStatus.completed})),
          const SizedBox(height: AppSizes.spaceSmall),
          _summaryRow(
            'Bekleyen / işlenen',
            _totalsFor(const {PayoutStatus.pending, PayoutStatus.processing}),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, List<_CurrencyTotal> totals) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spaceSmall),
        Flexible(
          child: Text(
            totals
                .map(
                  (total) => TurkishMoneyFormatter.format(
                    total.amount,
                    total.currency,
                  ),
                )
                .join(' + '),
            textAlign: TextAlign.end,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  /// Ödeme satırı; dokununca hakedişin detayı açılıyor ([PayoutDetailSheet]),
  /// işin detayına oradan geçiliyor.
  ///
  /// İş adı sunucunun `jobTitle` alanından; eski sunucuda ikinci istekle
  /// gelen atama listesinden (yalnız ilk sayfa). İkisi de yoksa satır adsız,
  /// yine tıklanabilir — iş detayı dokunma anında kimliğiyle çekiliyor
  /// ([_openWork]).
  Widget _payoutCard(Payout payout) {
    final assignment = _assignments[payout.jobAssignmentId];
    final isOpening = _openingPayoutId == payout.id;

    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        key: ValueKey('payout-${payout.id}'),
        borderRadius: AppRadius.innerCircular,
        onTap: _openingPayoutId != null ? null : () => _openDetail(payout),
        child: Padding(
          padding: AppPadding.card,
          child: _payoutBody(
            payout,
            jobTitle: payout.jobTitle ?? assignment?.job.title,
            isOpening: isOpening,
          ),
        ),
      ),
    );
  }

  Widget _payoutBody(
    Payout payout, {
    required String? jobTitle,
    required bool isOpening,
  }) {
    final ibanTail = payout.ibanTail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                TurkishMoneyFormatter.format(payout.amount, payout.currency),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isOpening) ...[
              const SizedBox.square(
                dimension: AppSizes.iconSmall,
                child: CircularProgressIndicator(strokeWidth: _spinnerStroke),
              ),
              const SizedBox(width: AppSizes.spaceSmall),
            ],
            PayoutStatusBadge(status: payout.status),
          ],
        ),
        const SizedBox(height: AppSizes.spaceTiny),
        Text(
          payout.status.description,
          style: context.textTheme.labelMedium?.copyWith(
            color: PayoutStatusBadge.colorOf(payout.status),
          ),
        ),
        if (jobTitle != null) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          Text(jobTitle, style: context.textTheme.bodyMedium),
        ],
        if (ibanTail != null) ...[
          const SizedBox(height: AppSizes.spaceTiny),
          Row(
            children: [
              AppIcon(
                AppIcons.bank,
                size: AppSizes.iconSmall,
                color: context.textSecondary,
              ),
              const SizedBox(width: AppSizes.spaceTiny),
              Text(
                "…$ibanTail IBAN'ına",
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSizes.spaceSmall),
        Text(
          payout.releasedAtOrCreated.toLocal().asShortDate,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.textTertiary,
          ),
        ),
        if (payout.status == PayoutStatus.failed) ...[
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            FinancialFailureMessage.payout(payout.failureReason),
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}
