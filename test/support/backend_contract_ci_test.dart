import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_contract_root.dart';

void main() {
  test('CI private koala-backend checkout yapmaz', () {
    final ci = File(
      '${BackendContractRoot.packageRoot().path}/.github/workflows/ci.yml',
    ).readAsStringSync();

    expect(ci, isNot(contains('repository: is-koala/koala-backend')));
    expect(ci, contains('Backend sözleşmesini bağla'));
  });
}
