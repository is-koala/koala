import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_contract_root.dart';

void main() {
  test('CI private koala-backend checkout yapmaz', () {
    final ci = File(
      '${BackendContractRoot.packageRoot().path}/.github/workflows/ci.yml',
    ).readAsStringSync();

    // GITHUB_TOKEN başka bir private depoyu okuyamaz (PR 144: Not Found);
    // hosted runner'da sözleşme testleri skip olur, suite durmaz.
    expect(ci, isNot(contains('repository: is-koala/koala-backend')));
  });
}
