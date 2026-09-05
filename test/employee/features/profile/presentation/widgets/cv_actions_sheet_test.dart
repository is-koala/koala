import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/profile/presentation/widgets/cv_actions_sheet.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';

import '../../../../../support/pump.dart';

void main() {
  group('Özgeçmiş eylem sayfası', () {
    testWidgets('özgeçmiş yokken yalnız yükleme eylemini gösterir', (
      tester,
    ) async {
      var uploadCount = 0;

      await pumpInApp(
        tester,
        CvActionsSheet(
          hasCv: false,
          onUpload: () => uploadCount++,
          onDelete: () {},
        ),
      );

      expect(find.byType(AppBottomSheet), findsOneWidget);
      expect(find.byType(AppIcon), findsOneWidget);
      expect(find.text('Özgeçmiş Yükle'), findsOneWidget);
      expect(find.text('Özgeçmişi Kaldır'), findsNothing);

      await tester.tap(find.text('Özgeçmiş Yükle'));
      expect(uploadCount, 1);
    });

    testWidgets('özgeçmiş varken değiştirme ve kaldırma eylemlerini sunar', (
      tester,
    ) async {
      var deleteCount = 0;

      await pumpInApp(
        tester,
        CvActionsSheet(
          hasCv: true,
          onUpload: () {},
          onDelete: () => deleteCount++,
        ),
      );

      expect(find.text('Özgeçmişi Değiştir'), findsOneWidget);
      expect(find.text('Özgeçmişi Kaldır'), findsOneWidget);

      await tester.tap(find.text('Özgeçmişi Kaldır'));
      expect(deleteCount, 1);
    });
  });
}
