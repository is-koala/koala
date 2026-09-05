import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/user_block.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/user_block_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/empty_state.dart';

/// Kullanıcının engellediği kişilerin listesi ("Engellediklerim").
///
/// Ekranın kendisi değil gövdesi: `Scaffold` ve başlık çubuğu çağırana ait,
/// çünkü iki uygulamanın başlık çubuğu farklı kuruluyor — [SessionView] ve
/// [ReportView] ile aynı düzen.
///
/// Liste **sayfalı değil**: `GET /users/me/blocks` düz bir liste döndürüyor,
/// o yüzden burada [ReportView]'deki sonsuz kaydırma yok.
class BlockedUsersView extends StatefulWidget {
  const BlockedUsersView({
    super.key,
    this.bottomPadding = AppSizes.space,
    this.service,
  });

  /// Listenin altındaki boşluk. İşveren tarafında navbar'ın altında
  /// kalmasın diye büyütülüyor.
  final double bottomPadding;

  /// Yalnızca testlerin sahte istemci geçebilmesi için; uygulamada boş
  /// bırakılıyor ve tekil servis kullanılıyor.
  final UserBlockService? service;

  @override
  State<BlockedUsersView> createState() => _BlockedUsersViewState();
}

class _BlockedUsersViewState extends State<BlockedUsersView> {
  late final UserBlockService _service = widget.service ?? UserBlockService();

  List<UserBlock> _blocks = const [];
  bool _isLoading = true;
  bool _isWorking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      final blocks = await _service.fetchMyBlocks();
      if (!mounted) return;
      setState(() {
        _blocks = blocks;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Engeli kaldırır ve satırı listeden düşürür.
  ///
  /// Liste yeniden çekilmiyor, kayıt elde siliniyor: uç idempotent ve tek
  /// bir kaydı kaldırıyor — başka satırı etkilemesinin yolu yok. Kullanıcı
  /// sonucu beklemeden görüyor.
  Future<void> _unblock(UserBlock block) async {
    final name = block.blocked.displayName;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Engeli kaldır',
      message:
          '$name ile yeniden mesajlaşabileceksiniz. İstersen aynı kişiyi '
          'sonra tekrar engelleyebilirsin.',
      actionLabel: 'Kaldır',
      isDestructive: false,
    );

    if (confirmed != true || _isWorking || !mounted) return;

    setState(() => _isWorking = true);

    try {
      await _service.unblock(block.blocked.id);
      if (!mounted) return;
      setState(() {
        _blocks = _blocks.where((other) => other.id != block.id).toList();
      });
      AppToast.success(context, 'Engel kaldırıldı');
    } on ApiException catch (error) {
      if (mounted) AppToast.error(context, error.message);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Üç durum ayrı ayrı çiziliyor: yükleniyor, açılamadı, gerçekten boş.
    if (_isLoading && _blocks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_blocks.isEmpty && _errorMessage != null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Engellediklerin açılamadı',
        description: _errorMessage!,
        action: TextButton(
          onPressed: () => _load(),
          child: const Text('Tekrar Dene'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _blocks.isEmpty
          ? const EmptyState(
              icon: AppIcons.userBlock,
              title: 'Engellediğin kimse yok',
              description:
                  'Bir kullanıcıyı engellersen burada görünür ve engeli '
                  'buradan kaldırabilirsin.',
            )
          : ListView.builder(
              padding: EdgeInsets.only(
                top: AppSizes.spaceSmall,
                bottom: widget.bottomPadding,
              ),
              itemCount: _blocks.length,
              itemBuilder: (context, index) => _tile(_blocks[index]),
            ),
    );
  }

  Widget _tile(UserBlock block) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.dividerColor, width: 1),
        ),
      ),
      child: Padding(
        padding: AppPadding.tileTall,
        child: Row(
          children: [
            Container(
              width: AppSizes.iconTile,
              height: AppSizes.iconTile,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(
                  alpha: AppColors.surfaceTintAlpha,
                ),
                borderRadius: AppRadius.innerCircular,
              ),
              child: const AppIcon(
                AppIcons.userBlock,
                size: AppSizes.icon,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: AppSizes.space),
            Expanded(child: _tileContent(block)),
            TextButton(
              onPressed: _isWorking ? null : () => _unblock(block),
              child: const Text('Engeli Kaldır'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileContent(UserBlock block) {
    final createdAt = block.createdAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          block.blocked.displayName,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (createdAt != null) ...[
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            '${createdAt.asShortDate} tarihinde engellendi',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}
