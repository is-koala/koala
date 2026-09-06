import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/business/features/home/presentation/pages/b_company_gallery_page.dart';
import 'package:koala/business/features/home/presentation/providers/b_company_provider.dart';
import 'package:koala/business/features/home/services/b_company_service.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/company_detail/services/company_service.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/product/theme/theme.dart';
import 'package:provider/provider.dart';

import '../../../../../support/fake_api.dart';

Map<String, dynamic> _imageJson(
  String id, {
  bool cover = false,
  int order = 0,
}) {
  return {
    'id': id,
    'url': 'https://cdn.local/$id.png',
    'sortOrder': order,
    'cover': cover,
    'caption': null,
  };
}

/// `/users/me`, `GET /companies/{id}` ve istatistik uçlarını birlikte
/// karşılayan sahte sunucu.
FakeApi _buildApi({
  required String role,
  required List<Map<String, dynamic>> images,
}) {
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

      if (options.path == '/companies/comp_1') {
        return FakeApiResponse(
          statusCode: 200,
          body: {
            'success': true,
            'data': {
              'id': 'comp_1',
              'name': 'Kahve Durağı',
              'type': 'LIMITED',
              'images': images,
            },
          },
        );
      }

      return const FakeApiResponse(
        statusCode: 200,
        body: {
          'success': true,
          'data': {'userId': 'user_1', 'jobsPosted': 1},
        },
      );
    },
  );
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  required String role,
  List<Map<String, dynamic>> images = const [],
  Brightness brightness = Brightness.light,
}) async {
  final api = _buildApi(role: role, images: images);
  final userProvider = UserProvider(
    userService: UserService.withClient(api.client),
  );
  // `testWidgets` gövdesi sahte bir saatte çalışıyor; gerçek zamanlamayı
  // gerektiren istek `runAsync` içinde atılmalı.
  await tester.runAsync(userProvider.load);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(
          create: (_) => BCompanyProvider(
            service: BCompanyService.withClient(api.client),
            companyService: CompanyService.withClient(api.client),
          ),
        ),
      ],
      child: MaterialApp(
        theme: brightness == Brightness.dark ? darkTheme : lightTheme,
        home: const BCompanyGalleryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('BCompanyGalleryPage', () {
    testWidgets('ADMIN yönetim denetimlerini görüyor', (tester) async {
      await _pumpGallery(
        tester,
        role: 'ADMIN',
        images: [_imageJson('img_1', cover: true)],
      );

      expect(find.text('Görsel Ekle'), findsOneWidget);
      expect(find.text('Kaldır'), findsOneWidget);
      expect(find.text('Kapak'), findsOneWidget);
    });

    testWidgets('STAFF galeriyi görüyor ama denetimleri görmüyor', (
      tester,
    ) async {
      await _pumpGallery(
        tester,
        role: 'STAFF',
        images: [
          _imageJson('img_1', cover: true),
          _imageJson('img_2', order: 1),
        ],
      );

      // Yetkisiz kullanıcı sunucudan `403` değil `404` alıyor
      // (`requireCompanyAdmin` `ResourceNotFoundException` fırlatıyor), yani
      // "Şirket bulunamadı" mesajı görürdü. Doğrusu düğmeyi hiç göstermemek.
      expect(find.text('Görsel Ekle'), findsNothing);
      expect(find.text('Kaldır'), findsNothing);
      expect(find.text('Kapak Yap'), findsNothing);
      // Galeri yine de çiziliyor.
      expect(find.byType(Image), findsNWidgets(2));
      expect(find.text('Kapak'), findsOneWidget);
    });

    testWidgets('on görsel doluyken ekleme kapalı ve nedeni yazıyor', (
      tester,
    ) async {
      await _pumpGallery(
        tester,
        role: 'ADMIN',
        images: [
          for (var index = 0; index < 10; index++)
            _imageJson('img_$index', cover: index == 0, order: index),
        ],
      );

      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Görsel Ekle'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('Galeri dolu'), findsOneWidget);
    });

    testWidgets('galeri boşken boş durum çiziliyor', (tester) async {
      await _pumpGallery(tester, role: 'ADMIN');

      expect(find.text('Galeride görsel yok'), findsOneWidget);
      // Boş galeride bile ekleme yolu açık kalmalı.
      expect(find.text('Görsel Ekle'), findsOneWidget);
    });

    testWidgets('koyu temada da çiziliyor', (tester) async {
      await _pumpGallery(
        tester,
        role: 'ADMIN',
        images: [_imageJson('img_1', cover: true)],
        brightness: Brightness.dark,
      );

      expect(find.text('Görsel Ekle'), findsOneWidget);
    });
  });
}
