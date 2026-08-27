import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_radius.dart';

/// Profil fotoğrafı.
///
/// Backend bir R2 bağlantısı döndürüyor; kullanıcı fotoğraf yüklemediyse alan
/// `null` geliyor. Bağlantı ölü de olabildiği için hem boş hem hatalı durumda
/// varsayılan koala görseline düşülüyor — kırık görsel ikonu gösterilmiyor.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    return ClipRRect(
      borderRadius: AppRadius.secondaryCircular,
      child: SizedBox(
        width: size,
        height: size,
        child: url == null || url.isEmpty
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() =>
      Image.asset(AppAssets.defaultProfilePicture, fit: BoxFit.cover);
}
