import 'dart:convert';
import 'dart:io';

import 'backend_contract_root.dart';

/// Backend'in yayımladığı `ErrorCategory` kümesini okur.
///
/// Önce `KOALA_OPENAPI_PATH` (OpenAPI belgesi), yoksa
/// [BackendContractRoot] üzerinden `ErrorCategory.java`. İkinci bir Dart
/// listesi değil; Java/şema eklenince eşleme testi kırmızıya döner.
class BackendErrorCategories {
  static const javaRelativePath = BackendContractRoot.identityRelativePath;

  static Set<String> load({Directory? from, Map<String, String>? environment}) {
    final env =
        environment ??
        (from == null ? Platform.environment : const <String, String>{});
    final openApiPath = env['KOALA_OPENAPI_PATH'];
    if (openApiPath != null && openApiPath.isNotEmpty) {
      final file = File(openApiPath);
      if (!file.existsSync()) {
        throw StateError('KOALA_OPENAPI_PATH ($openApiPath) okunamadı.');
      }
      return parseOpenApi(file.readAsStringSync());
    }

    final root = BackendContractRoot.resolve(
      from: from,
      environment: environment,
    );
    final javaFile = File('${root.path}/$javaRelativePath');
    if (!javaFile.existsSync()) {
      throw StateError(
        'ErrorCategory.java bulunamadı: ${javaFile.path}. '
        'KOALA_BACKEND_ROOT, KOALA_OPENAPI_PATH veya kardeş '
        'koala-backend fixture gerekli.',
      );
    }
    return parseJava(javaFile.readAsStringSync());
  }

  static Set<String> parseJava(String source) {
    final match = RegExp(
      r'enum\s+ErrorCategory\s*\{([^}]*)\}',
    ).firstMatch(source);
    if (match == null) {
      throw StateError('ErrorCategory enum gövdesi bulunamadı.');
    }
    final constantsPart = match.group(1)!.split(';').first;
    final withoutComments = constantsPart
        .replaceAll(RegExp(r'//.*'), '')
        .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final names = RegExp(
      r'\b([A-Z][A-Z0-9_]*)\b',
    ).allMatches(withoutComments).map((m) => m.group(1)!).toSet();
    if (names.isEmpty) {
      throw StateError('ErrorCategory.java içinde sabit yok.');
    }
    return names;
  }

  static Set<String> parseOpenApi(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('OpenAPI belgesi bir nesne değil.');
    }
    final property = _at(decoded, [
      'components',
      'schemas',
      'ErrorResult',
      'properties',
      'errorCategory',
    ]);
    final fromProperty = _enumValues(decoded, property);
    if (fromProperty.isNotEmpty) return fromProperty;

    final named = _enumValues(
      decoded,
      _at(decoded, ['components', 'schemas', 'ErrorCategory']),
    );
    if (named.isEmpty) {
      throw StateError('OpenAPI belgesinde ErrorCategory enum listesi yok.');
    }
    return named;
  }

  static Object? _at(Object? node, List<String> path) {
    Object? current = node;
    for (final segment in path) {
      if (current is! Map) return null;
      current = current[segment];
    }
    return current;
  }

  static Set<String> _enumValues(
    Map<String, dynamic> document,
    Object? schema,
  ) {
    if (schema is! Map) return {};
    final values = schema['enum'];
    if (values is List) {
      return values.whereType<String>().toSet();
    }
    final ref = schema[r'$ref'];
    if (ref is String && ref.startsWith('#/')) {
      return _enumValues(document, _at(document, ref.substring(2).split('/')));
    }
    for (final combinator in ['oneOf', 'anyOf', 'allOf']) {
      final options = schema[combinator];
      if (options is! List) continue;
      final combined = <String>{};
      for (final option in options) {
        combined.addAll(_enumValues(document, option));
      }
      if (combined.isNotEmpty) return combined;
    }
    return {};
  }
}
