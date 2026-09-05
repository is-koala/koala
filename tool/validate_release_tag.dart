import 'dart:io';

String? releaseValidationError({
  required String tag,
  required String pubspecContent,
  required String appInfoContent,
}) {
  final pubspecMatch = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+[0-9]+)?\s*$',
    multiLine: true,
  ).firstMatch(pubspecContent);
  final appInfoMatch = RegExp(
    r"static const String version = '([0-9]+\.[0-9]+\.[0-9]+)';",
  ).firstMatch(appInfoContent);

  if (pubspecMatch == null) {
    return 'pubspec.yaml içinde geçerli bir semver sürümü bulunamadı.';
  }
  if (appInfoMatch == null) {
    return 'AppInfo.version içinde geçerli bir semver sürümü bulunamadı.';
  }

  final pubspecVersion = pubspecMatch.group(1)!;
  final appVersion = appInfoMatch.group(1)!;
  if (pubspecVersion != appVersion) {
    return 'pubspec ($pubspecVersion) ile AppInfo ($appVersion) eşleşmiyor.';
  }

  final expectedTag = 'mobile-v$pubspecVersion';
  if (tag != expectedTag) {
    return 'Etiket $tag değil, $expectedTag olmalı.';
  }

  return null;
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Kullanım: dart run tool/validate_release_tag.dart <etiket>',
    );
    exitCode = 64;
    return;
  }

  final error = releaseValidationError(
    tag: arguments.single,
    pubspecContent: File('pubspec.yaml').readAsStringSync(),
    appInfoContent: File(
      'lib/product/constants/app_info.dart',
    ).readAsStringSync(),
  );

  if (error != null) {
    stderr.writeln(error);
    exitCode = 1;
    return;
  }

  stdout.writeln('Mobil release etiketi sürüm sözleşmesiyle eşleşiyor.');
}
