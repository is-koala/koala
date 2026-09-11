import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_contacts_page.dart';
import 'package:koala/business/features/home/services/company_contact_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

const _admin = {
  'id': 'user_1',
  'firstName': 'Ali',
  'lastName': 'Veli',
  'username': 'ali',
};

const _staff = {
  'id': 'user_2',
  'firstName': 'Ayşe',
  'lastName': 'Yılmaz',
  'username': 'ayse',
};

FakeApi _buildApi({required String role}) {
  return FakeApi(
    handler: (options) {
      if (options.path == '/users/me') {
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'user_1',
              'firstName': 'Ali',
              'lastName': 'Veli',
              'email': 'ali@example.com',
              'isEmployer': true,
              'companies': [
                {
                  'companyId': 'comp_1',
                  'companyName': 'Kahve Durağı',
                  'approved': true,
                  'role': role,
                },
              ],
            },
          },
        );
      }

      if (options.path == '/companies/comp_1/contacts') {
        return const FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': [
              {'id': 'contact-1', 'user': _admin, 'role': 'ADMIN'},
              {'id': 'contact-2', 'user': _staff, 'role': 'STAFF'},
            ],
          },
        );
      }

      return const FakeApiResponse(statusCode: 404, body: {'success': false});
    },
  );
}

Future<void> _pumpContacts(WidgetTester tester, {required String role}) async {
  final api = _buildApi(role: role);
  final userProvider = UserProvider(
    userService: UserService.withClient(api.client),
  );
  await tester.runAsync(userProvider.load);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: userProvider,
      child: MaterialApp(
        theme: lightTheme,
        home: BCompanyContactsPage(
          service: CompanyContactService.withClient(api.client),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BCompanyContactsPage', () {
    testWidgets('ADMIN davet ve çıkarma düğmelerini görüyor', (tester) async {
      await _pumpContacts(tester, role: 'ADMIN');

      expect(find.text('Ali Veli'), findsOneWidget);
      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.text('Yönetici'), findsOneWidget);
      expect(find.text('Çalışan'), findsOneWidget);
      expect(find.byTooltip('Yetkili Davet Et'), findsOneWidget);
      expect(find.byTooltip('Yetkiliyi çıkar'), findsNWidgets(2));
    });

    testWidgets('STAFF listeyi görüyor ama yönetim düğmelerini görmüyor', (
      tester,
    ) async {
      await _pumpContacts(tester, role: 'STAFF');

      expect(find.text('Ayşe Yılmaz'), findsOneWidget);
      expect(find.byTooltip('Yetkili Davet Et'), findsNothing);
      expect(find.byTooltip('Yetkiliyi çıkar'), findsNothing);
      expect(find.byType(AppIcon), findsWidgets);
    });
  });
}
