import 'package:flutter/material.dart';
import 'package:koala/business/features/home/presentation/providers/b_talent_pool_provider.dart';
import 'package:koala/business/features/home/services/talent_pool_service.dart';
import 'package:koala/employee/features/home/models/job_detail.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/reason_dialog.dart';
import 'package:provider/provider.dart';

/// Adayı yetenek havuzuna ekleyen / çıkaran yer imi düğmesi.
///
/// Üyelik bilinmiyorken dolu çizilmez ve dokununca önce sayfalar yüklenir.
/// Havuzdaysa ikinci dokunuş `DELETE` atar — gövdesiz `PUT` var olan notu
/// silerdi.
class BTalentPoolButton extends StatefulWidget {
  const BTalentPoolButton({super.key, required this.worker, this.iconSize});

  final JobCreator worker;
  final double? iconSize;

  @override
  State<BTalentPoolButton> createState() => _BTalentPoolButtonState();
}

class _BTalentPoolButtonState extends State<BTalentPoolButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final membership = context.watch<BTalentPoolProvider>().isInPool(
      widget.worker.id,
    );
    final inPool = membership == TalentPoolMembership.yes;

    return IconButton(
      tooltip: inPool ? 'Havuzdan çıkar' : 'Yetenek havuzuna ekle',
      onPressed: _busy ? null : () => _toggle(context),
      icon: AppIcon(
        AppIcons.bookmark,
        filled: inPool,
        size: widget.iconSize ?? AppSizes.icon,
        color: context.textPrimary,
      ),
    );
  }

  Future<void> _toggle(BuildContext context) async {
    final provider = context.read<BTalentPoolProvider>();
    setState(() => _busy = true);

    try {
      final membership = await provider.ensureMembership(widget.worker.id);
      if (!context.mounted) return;

      if (membership == TalentPoolMembership.unknown) {
        AppToast.error(
          context,
          provider.errorMessage ?? 'Havuz durumu alınamadı.',
        );
        return;
      }

      if (membership == TalentPoolMembership.yes) {
        final removed = await provider.removeWorker(widget.worker.id);
        if (!removed && context.mounted) {
          AppToast.error(
            context,
            provider.errorMessage ?? 'Havuzdan çıkarılamadı.',
          );
        }
        return;
      }

      final note = await ReasonDialog.show(
        context,
        title: 'Yetenek havuzuna ekle',
        description:
            '${widget.worker.fullName} havuza eklenecek. '
            'Bir not bırakabilirsiniz.',
        fieldLabel: 'Not',
        confirmLabel: 'Ekle',
        isDestructive: false,
        maxLength: TalentPoolService.maxNoteLength,
      );
      if (note == null || !context.mounted) return;

      final added = await provider.addWorker(widget.worker, note: note);
      if (!added && context.mounted) {
        AppToast.error(context, provider.errorMessage ?? 'Havuza eklenemedi.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
