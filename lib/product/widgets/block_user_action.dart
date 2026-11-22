import 'package:material_ui/material_ui.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/user_block_service.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';

/// Engelleme akışı: onay, istek, sonuç bildirimi. Sohbet menüsü ve aday profili
/// aynı akışı kullansın diye tek yerde.
///
/// ```dart
/// await BlockUserAction.confirmAndBlock(context, userId: id, name: name);
/// ```
abstract final class BlockUserAction {
  /// Onay alır ve engeller; engellendiyse `true`. Menüden yanlışlıkla
  /// dokunulabildiği ve mesajlaşmayı kapattığı için onaysız istek atılmaz.
  /// Gerekçe sorulmuyor: sunucu isteğe bağlı tutuyor, kimse okumuyor.
  static Future<bool> confirmAndBlock(
    BuildContext context, {
    required String userId,
    String? name,
    UserBlockService? service,
  }) async {
    final displayName = name?.trim();
    final subject = displayName == null || displayName.isEmpty
        ? 'Bu kullanıcıyla'
        : '$displayName ile';

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Kullanıcıyı engelle',
      // Engel iki yönlü; kullanıcı yalnız "ben ona yazamam" sanmamalı.
      message:
          '$subject mesajlaşma kapanacak: sen ona, o da sana yazamaz. '
          'Engeli Ayarlar\'daki "Engellediklerim" ekranından '
          'kaldırabilirsin.',
      actionLabel: 'Engelle',
    );

    if (confirmed != true || !context.mounted) return false;

    try {
      await (service ?? UserBlockService()).block(userId);
      if (context.mounted) AppToast.success(context, 'Kullanıcı engellendi');
      return true;
    } on ApiException catch (error) {
      if (context.mounted) AppToast.error(context, error.message);
      return false;
    }
  }
}
