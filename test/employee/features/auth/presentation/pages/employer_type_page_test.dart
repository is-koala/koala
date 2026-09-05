import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/auth/presentation/pages/employer_type_page.dart';

void main() {
  testWidgets('işveren bireysel veya şirket olarak devam edebilir', (
    tester,
  ) async {
    var selection = '';

    await tester.pumpWidget(
      MaterialApp(
        home: EmployerTypePage(
          onIndividualSelected: () => selection = 'individual',
          onCompanySelected: () => selection = 'company',
        ),
      ),
    );

    expect(find.text('Bireysel İşveren'), findsOneWidget);
    expect(find.text('Şirket Olarak Devam Et'), findsOneWidget);

    await tester.tap(find.text('Bireysel İşveren'));
    expect(selection, 'individual');

    await tester.tap(find.text('Şirket Olarak Devam Et'));
    expect(selection, 'company');
  });
}
