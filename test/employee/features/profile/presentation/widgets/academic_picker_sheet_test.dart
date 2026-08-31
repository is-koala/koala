import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/presentation/widgets/academic_picker_sheet.dart';
import 'package:koala/product/models/academic_reference.dart';

import '../../../../../support/pump.dart';

const List<AcademicReference> _items = [
  AcademicReference(id: 'uni_1', name: 'Boğaziçi Üniversitesi'),
  AcademicReference(id: 'uni_2', name: 'Ankara Üniversitesi'),
];

Future<void> openSheet(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
}) async {
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => AcademicPickerSheet.show(
          context,
          title: 'Üniversite',
          items: _items,
        ),
        child: const Text('aç'),
      ),
    ),
    brightness: brightness,
  );

  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  // `ListTile` kullanılırsa Flutter "background color or ink splashes may be
  // invisible" hatasını bildiriyor: `AppBottomSheet`'in renkli kabuğu araya
  // giriyor. Bu test o gerilemeyi tutuyor.
  testWidgets('liste ListTile kullanmıyor', (tester) async {
    await openSheet(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsNothing);
    expect(find.text('Boğaziçi Üniversitesi'), findsOneWidget);
  });

  // Arama Türkçe karakterleri katlıyor: kullanıcı "bogazici" yazınca
  // "Boğaziçi" bulunmalı.
  testWidgets('arama Türkçe karakter ayrımı yapmıyor', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'bogazici');
    await tester.pumpAndSettle();

    expect(find.text('Boğaziçi Üniversitesi'), findsOneWidget);
    expect(find.text('Ankara Üniversitesi'), findsNothing);
  });

  testWidgets('eşleşme yoksa sonuç yok yazıyor', (tester) async {
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Sonuç yok'), findsOneWidget);
  });

  testWidgets('seçilen kayıt geri döndürülüyor', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Ankara Üniversitesi'));
    await tester.pumpAndSettle();

    expect(find.text('Ankara Üniversitesi'), findsNothing);
  });

  testWidgets('koyu temada da çizilir', (tester) async {
    await openSheet(tester, brightness: Brightness.dark);

    expect(tester.takeException(), isNull);
    expect(find.text('Boğaziçi Üniversitesi'), findsOneWidget);
  });
}
