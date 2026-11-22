import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_assets.dart';
import 'package:koala/product/constants/app_radius.dart';

/// Profil fotoğrafı; yoksa ya da bağlantı ölüyse varsayılan koala görseli,
/// kırık ikon değil.
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
