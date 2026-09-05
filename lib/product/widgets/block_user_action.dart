import 'package:flutter/material.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/services/user_block_service.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';

/// Kullanıcı engelleme akışı: onay kutusu, istek ve sonucun bildirimi.
///
/// İki giriş noktası var — sohbet başlığındaki taşma menüsü ve işverenin
/// gördüğü aday profili — ve ikisinde de aynı üç adım yürüyor. Metni ve hata
/// işlemesini iki yerde tekrarlamak, ikisinin bir gün ayrışması demekti;
/// [ReportSheet] da aynı sebeple gönderimi kendi içinde yapıyor.
///
/// Widget değil ama `widgets/` altında: çizdiği şey bir onay kutusu ve bir
/// toast — [AppToast] gibi.
///
/// ```dart
/// await BlockUserAction.confirmAndBlock(
///   context,
///   userId: chat.counterpartId,
///   name: chat.name,
/// );
/// ```
abstract final class BlockUserAction {
  /// Onay alır ve kullanıcıyı engeller. Engellendiyse `true` döner.
  ///
  /// Onay kutusu geçilmeden istek **atılmıyor**: engelleme kullanıcının
  /// yanlışlıkla dokunabileceği bir menü maddesinden başlıyor ve sonucu
  /// karşılıklı mesajlaşmayı kapatıyor.
  ///
  /// Gerekçe gönderilmiyor: sunucu isteğe bağlı tutuyor ve yalnızca
  /// moderasyona kaydediyor — engelleme sebebini moderasyona taşımak ayrı
  /// bir iş. Kullanıcıdan kimsenin okumayacağı bir metin istemek yerine
  /// engel tek dokunuşta kuruluyor.
  ///
  /// [service] yalnızca testlerin sahte istemci geçebilmesi için var.
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
      // Engel iki yönlü (`MessagingManager.java:294-298`): kullanıcı yalnızca
      // "ben ona yazamayacağım" sanmamalı.
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
      // Sunucu `Accept-Language: tr` ile zaten Türkçe döndürüyor; metni
      // yeniden yazmıyoruz.
      if (context.mounted) AppToast.error(context, error.message);
      return false;
    }
  }
}
