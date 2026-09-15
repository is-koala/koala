import 'dart:io';

import 'backend_contract_root.dart';

/// Backend `errorCode` kümesi: `messages_tr.properties` anahtarlarından
/// `KoalaException.deriveErrorCode` ile aynı dönüşüm.
///
/// Mobil yönlendirme bu dizgelere bakıyor. Fixture'ı koda bakarak yazmak
/// ikisini birlikte yanlış bırakır (is-koala/koala#89); kaynak properties.
class BackendErrorCodes {
  static const propertiesRelativePath =
      'src/main/resources/messages_tr.properties';

  static const routingSources = [
    'lib/employee/features/jobs/presentation/providers/job_alerts_provider.dart',
    'lib/employee/features/jobs/models/application_readiness.dart',
    'lib/employee/features/auth/presentation/company_identity_gate.dart',
    'lib/employee/features/settings/models/identity_error.dart',
    'lib/employee/features/settings/models/identity_document_error.dart',
    'lib/business/features/home/presentation/providers/b_job_templates_provider.dart',
    'lib/business/features/home/services/employer_job_service.dart',
    'lib/business/features/home/models/worker_identity_error_codes.dart',
    'lib/employee/features/jobs/presentation/providers/review_provider.dart',
    'lib/employee/features/jobs/presentation/providers/timesheet_queue_provider.dart',
    'lib/employee/features/chat/models/messaging_gate_error_codes.dart',
    'lib/product/features/account/models/address_required_error_codes.dart',
    'lib/product/models/address_reverse_error_codes.dart',
  ];

  static final _quotedCode = RegExp(r"'([A-Z][A-Z0-9_]{2,})'");

  static Set<String> load({Directory? from, Map<String, String>? environment}) {
    final root = BackendContractRoot.resolve(
      from: from,
      environment: environment,
    );
    final file = File('${root.path}/$propertiesRelativePath');
    if (!file.existsSync()) {
      throw StateError(
        'messages_tr.properties bulunamadı: ${file.path}. '
        'KOALA_BACKEND_ROOT veya kardeş koala-backend fixture gerekli.',
      );
    }
    return parseProperties(file.readAsStringSync());
  }

  static String deriveErrorCode(String messageKey) {
    var key = messageKey.trim();
    if (key.startsWith('{') && key.endsWith('}')) {
      key = key.substring(1, key.length - 1);
    }
    return key.replaceAll('.', '_').replaceAll('-', '_').toUpperCase();
  }

  static Set<String> parseProperties(String source) {
    final codes = <String>{};
    for (final rawLine in source.split('\n')) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('!')) {
        continue;
      }
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      codes.add(deriveErrorCode(line.substring(0, separator).trim()));
    }
    if (codes.isEmpty) {
      throw StateError('messages_tr.properties içinde anahtar yok.');
    }
    return codes;
  }

  static Set<String> routedCodesIn(String dartSource) {
    return _quotedCode.allMatches(dartSource).map((m) => m.group(1)!).toSet();
  }

  static Set<String> routedCodesFromLib({Directory? from}) {
    final root = from ?? BackendContractRoot.packageRoot();
    final codes = <String>{};
    for (final relative in routingSources) {
      final file = File('${root.path}/$relative');
      if (!file.existsSync()) {
        throw StateError('Yönlendirme kaynağı yok: ${file.path}');
      }
      codes.addAll(routedCodesIn(file.readAsStringSync()));
    }
    return codes;
  }
}
