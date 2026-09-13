import 'dart:io';

/// Backend sözleşme kökü — tek resolver (is-koala/koala#139).
///
/// `from` verilmişse yalnızca o dizin, içindeki `koala-backend` ve
/// bir üst kardeş bakılır; süreç ortamı ve üst atalar fixture
/// sınırını aşamaz. `from` yoksa `KOALA_BACKEND_ROOT` /
/// `KOALA_BACKEND_PATH`, sonra paket kökünden yukarı kardeş aranır.
class BackendContractRoot {
  static const identityRelativePath =
      'src/main/java/com/exskylab/koala/core/utilities/results/ErrorCategory.java';

  static Directory resolve({
    Directory? from,
    Map<String, String>? environment,
  }) {
    final env =
        environment ??
        (from == null ? Platform.environment : const <String, String>{});
    final fromEnv = env['KOALA_BACKEND_ROOT'] ?? env['KOALA_BACKEND_PATH'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return Directory(fromEnv);
    }

    if (from != null) {
      final found = _near(from);
      if (found != null) return found;
      throw _missing(from);
    }

    final start = packageRoot();
    var dir = start;
    for (var i = 0; i < 8; i++) {
      final found = _near(dir);
      if (found != null) return found;
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }

    throw _missing(start);
  }

  /// `pubspec.yaml` görene kadar çalışma dizininden yukarı çıkar.
  static Directory packageRoot({Directory? from}) {
    var dir = from ?? Directory.current;
    for (var i = 0; i < 16; i++) {
      if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
      if (dir.parent.path == dir.path) break;
      dir = dir.parent;
    }
    throw StateError(
      'pubspec.yaml bulunamadı (cwd: ${(from ?? Directory.current).path}). '
      'Testleri paket kökünden çalıştırın.',
    );
  }

  static Directory? _near(Directory anchor) {
    for (final candidate in [
      anchor,
      Directory('${anchor.path}/koala-backend'),
      Directory('${anchor.parent.path}/koala-backend'),
    ]) {
      if (_looksLikeBackend(candidate)) return candidate;
    }
    return null;
  }

  static bool _looksLikeBackend(Directory dir) {
    return File('${dir.path}/$identityRelativePath').existsSync();
  }

  static StateError _missing(Directory from) {
    return StateError(
      'koala-backend bulunamadı (from: ${from.path}). '
      'KOALA_BACKEND_ROOT, KOALA_BACKEND_PATH veya KOALA_OPENAPI_PATH '
      'eksik; ya da fixture olarak kardeş koala-backend dizinini koyun.',
    );
  }
}
