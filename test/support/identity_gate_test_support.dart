import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/models/current_user.dart';

/// `/users/me` yanıtı: kimlik bayrağı ve şirket üyelikleri testin verdiği
/// hâlde, geri kalanı sabit bir işveren.
///
/// Şirket kapısı testleri aynı gövdeyi üç ayrı ekrandan sürüyor; her testte
/// yeniden yazmak bayrağın hangi testte neden değiştiğini gölgeliyor.
Map<String, dynamic> employerMeResponse({
  required bool identityVerified,
  List<Map<String, dynamic>> companies = const [],
}) {
  return {
    'success': true,
    'data': {
      'id': 'employer-1',
      'firstName': 'Ayşe',
      'lastName': 'İşveren',
      'email': 'ayse@example.com',
      'isEmployer': true,
      'identityVerified': identityVerified,
      'companies': companies,
    },
  };
}

/// Kimlik doğrulama ekranının yerine geçen sahte rota.
///
/// Gerçek `IdentityVerificationPage` `UserService()`'i kendisi kuruyor ve
/// ağa çıkıyor; kapıyı sürmek için ekranın yalnızca **sözleşmesi** gerekiyor:
/// `extra` olarak `CurrentUser` alır, başarıda `true` ile kapanır. Testler
/// [identityVerifiedKey] düğmesine basarak başarıyı, geri okuyla vazgeçmeyi
/// canlandırıyor. Açılırken aldığı kullanıcı [onOpened] ile dışarı veriliyor.
GoRoute stubIdentityVerificationRoute({
  void Function(CurrentUser user)? onOpened,
}) {
  return GoRoute(
    path: '/identity-verification',
    pageBuilder: (context, state) {
      final user = state.extra as CurrentUser;
      onOpened?.call(user);
      return MaterialPage<void>(
        key: state.pageKey,
        child: Scaffold(
          appBar: AppBar(title: const Text(identityStubTitle)),
          body: Center(
            child: ElevatedButton(
              key: identityVerifiedKey,
              onPressed: () => context.pop(true),
              child: const Text('Doğrulandı'),
            ),
          ),
        ),
      );
    },
  );
}

/// Sahte kimlik ekranının başlığı; "ekran açıldı" iddiası buna bakıyor.
const String identityStubTitle = 'Kimlik doğrulama ekranı';

/// Sahte kimlik ekranındaki "başarıyla doğrulandı" düğmesi.
const Key identityVerifiedKey = ValueKey('stub-identity-verified');
