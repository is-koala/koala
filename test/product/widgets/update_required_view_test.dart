import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_info.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/update_required_view.dart';

import '../../support/pump.dart';

void main() {
  const iosId = '1234567890';
  const androidId = 'com.iskoala.koala';

  group('mağaza adresi', () {
    test('iOS kimliği boşken Android kimliğine düşmüyor', () {
      expect(
        UpdateRequiredView.storeUriFor(
          platform: TargetPlatform.iOS,
          iosAppStoreId: '',
          androidPackageId: androidId,
        ),
        isNull,
      );
    });

    test('iOS kimliği doluyken App Store adresi üretiliyor', () {
      final uri = UpdateRequiredView.storeUriFor(
        platform: TargetPlatform.iOS,
        iosAppStoreId: iosId,
        androidPackageId: androidId,
      );

      expect(uri, Uri.parse('https://apps.apple.com/app/id$iosId'));
    });

    test('Android kimliği doluyken Play Store adresi üretiliyor', () {
      final uri = UpdateRequiredView.storeUriFor(
        platform: TargetPlatform.android,
        iosAppStoreId: '',
        androidPackageId: androidId,
      );

      expect(
        uri,
        Uri.parse('https://play.google.com/store/apps/details?id=$androidId'),
      );
    });

    test('Android kimliği boşken iOS kimliğine düşmüyor', () {
      expect(
        UpdateRequiredView.storeUriFor(
          platform: TargetPlatform.android,
          iosAppStoreId: iosId,
          androidPackageId: '',
        ),
        isNull,
      );
    });

    test('iki kimlik de boşken adres yok', () {
      expect(
        UpdateRequiredView.storeUriFor(
          platform: TargetPlatform.android,
          iosAppStoreId: '',
          androidPackageId: '',
        ),
        isNull,
      );
    });

    // Kimlikler dosyadan okunuyor: biri doldurulduğunda yedek yolun geri
    // gelmediğini bu test tutuyor.
    test('gerçek kimliklerle iOS hiçbir zaman Play Store adresi üretmiyor', () {
      final uri = UpdateRequiredView.storeUriFor(
        platform: TargetPlatform.iOS,
        iosAppStoreId: AppInfo.iosAppStoreId,
        androidPackageId: AppInfo.androidPackageId,
      );

      expect(uri?.host, anyOf(isNull, 'apps.apple.com'));
    });
  });

  group('güncelleme ekranı', () {
    testWidgets('iOS kimliği boşken düğme yerine yönlendirme metni çiziliyor', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const UpdateRequiredView(
          message: 'Lütfen uygulamayı güncelleyin.',
          iosAppStoreId: '',
          androidPackageId: androidId,
        ),
      );

      expect(find.byType(MyButton), findsNothing);
      expect(find.text('Mağazayı Aç'), findsNothing);
      expect(find.text('Lütfen uygulamayı güncelleyin.'), findsOneWidget);
      expect(find.textContaining('destek@iskoala.com'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('iki kimlik de boşken düğme yok ama açıklama duruyor', (
      tester,
    ) async {
      await pumpInApp(
        tester,
        const UpdateRequiredView(
          message: 'Lütfen uygulamayı güncelleyin.',
          iosAppStoreId: '',
          androidPackageId: '',
        ),
      );

      expect(find.byType(MyButton), findsNothing);
      expect(find.text('Lütfen uygulamayı güncelleyin.'), findsOneWidget);
      expect(find.textContaining('destek@iskoala.com'), findsOneWidget);
    });

    testWidgets('platformun kimliği doluyken düğme çiziliyor', (tester) async {
      await pumpInApp(
        tester,
        const UpdateRequiredView(
          message: 'Lütfen uygulamayı güncelleyin.',
          iosAppStoreId: iosId,
          androidPackageId: '',
        ),
      );

      expect(find.byType(MyButton), findsOneWidget);
      expect(find.text('Mağazayı Aç'), findsOneWidget);
      expect(find.textContaining('destek@iskoala.com'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
