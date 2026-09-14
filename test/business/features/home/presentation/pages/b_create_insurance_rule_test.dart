import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_create_page.dart';
import 'package:koala/business/features/home/presentation/widgets/b_selection_field.dart';
import 'package:koala/business/features/home/services/b_payment_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/home/services/job_category_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';
import '../../../../../support/pump.dart';

/// Sunucu kuralı: kategori sigorta zorunluysa şirket ilanı
/// `insuranceRequired=true` olmadan kabul edilmiyor (`JobManager`, `400`).
/// Bu testler o kuralın istemcide de tutulduğuna bakıyor.
const Map<String, dynamic> _insuranceCategory = {
  'id': 'cat-garson',
  'name': 'Garson',
  'code': 'GARSON',
  'requiresInsurance': true,
};

const Map<String, dynamic> _plainCategory = {
  'id': 'cat-foto',
  'name': 'Fotoğrafçılık',
  'code': 'FOTOGRAFCILIK',
  'requiresInsurance': false,
};

Finder _categoryField() =>
    find.widgetWithText(BSelectionField, 'Kategori *').first;

/// "Sigorta Gerekli" satırındaki anahtar.
Switch _insuranceSwitch(WidgetTester tester) => tester.widget<Switch>(
  find
      .descendant(
        of: find.widgetWithText(Row, 'Sigorta Gerekli'),
        matching: find.byType(Switch),
      )
      .first,
);

Future<void> _pickCategory(WidgetTester tester, String name) async {
  await tester.ensureVisible(_categoryField());
  await tester.pumpAndSettle();
  await tester.tap(_categoryField());
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// İlan oluşturma ekranını onaylı şirket üyeliği olan bir işverenle çizer.
Future<void> _pumpCompanyEmployer(WidgetTester tester) async {
  final userApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': {
          'id': 'employer-1',
          'firstName': 'Ayşe',
          'lastName': 'İşveren',
          'email': 'ayse@example.com',
          'isEmployer': true,
          'identityVerified': true,
          'companies': [
            {
              'companyId': 'company-1',
              'companyName': 'Koala A.Ş.',
              'approved': true,
              'role': 'OWNER',
            },
          ],
        },
      },
    ),
  );
  final userProvider = UserProvider(
    userService: UserService.withClient(userApi.client),
  );
  await tester.runAsync(userProvider.load);

  final categoryApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {
        'success': true,
        'data': [_insuranceCategory, _plainCategory],
      },
    ),
  );
  final emptyApi = FakeApi(
    handler: (_) => const FakeApiResponse(
      statusCode: 200,
      body: {'success': true, 'data': []},
    ),
  );

  await pumpInApp(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(
          create: (_) => JobCategoryProvider(
            service: JobCategoryService.withClient(categoryApi.client),
          ),
        ),
      ],
      child: BCreatePage(
        paymentService: BPaymentService.withClient(emptyApi.client),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sigorta zorunlu kategoride anahtar açılıyor ve kilitleniyor', (
    tester,
  ) async {
    await _pumpCompanyEmployer(tester);

    // Kategori seçilmeden önce anahtar kullanıcının bıraktığı hâlde.
    expect(_insuranceSwitch(tester).value, isFalse);
    expect(_insuranceSwitch(tester).onChanged, isNotNull);

    await _pickCategory(tester, 'Garson');

    expect(
      _insuranceSwitch(tester).value,
      isTrue,
      reason:
          'Sigorta zorunlu kategoride şirket ilanı sunucuda '
          'insuranceRequired=true olmadan kabul edilmiyor.',
    );
    expect(
      _insuranceSwitch(tester).onChanged,
      isNull,
      reason: 'Kural sunucuda zorunlu; anahtar kapatılabilir olmamalı.',
    );
    expect(
      find.text(
        'Bu kategoride sigortalı çalışma zorunlu, ilan bu şekilde yayınlanır.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('zorunlu olmayan kategoriye geçilince kilit kalkıyor', (
    tester,
  ) async {
    await _pumpCompanyEmployer(tester);

    await _pickCategory(tester, 'Garson');
    expect(_insuranceSwitch(tester).onChanged, isNull);

    await _pickCategory(tester, 'Fotoğrafçılık');

    expect(_insuranceSwitch(tester).onChanged, isNotNull);
    expect(
      _insuranceSwitch(tester).value,
      isFalse,
      reason:
          'Kilit kalkınca kullanıcının kendi tercihi geri gelmeli; sigorta '
          'zorlaması kategoriye bağlıydı.',
    );
  });

  testWidgets('kilitli değilken anahtar kullanıcının tercihini koruyor', (
    tester,
  ) async {
    await _pumpCompanyEmployer(tester);

    await _pickCategory(tester, 'Fotoğrafçılık');

    final switchFinder = find
        .descendant(
          of: find.widgetWithText(Row, 'Sigorta Gerekli'),
          matching: find.byType(Switch),
        )
        .first;
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(_insuranceSwitch(tester).value, isTrue);

    // Kilitlenip açılan kategori döngüsü kullanıcının kendi tercihini
    // silmemeli.
    await _pickCategory(tester, 'Garson');
    expect(_insuranceSwitch(tester).value, isTrue);
    await _pickCategory(tester, 'Fotoğrafçılık');
    expect(_insuranceSwitch(tester).value, isTrue);
    expect(_insuranceSwitch(tester).onChanged, isNotNull);
  });
}
