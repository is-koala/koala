import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/map_explore_controller.dart';
import 'package:koala/employee/features/home/presentation/widgets/map_explore_overlay.dart';

import '../../../../../support/pump.dart';

Job _job(String id) => Job.fromJson({
  'id': id,
  'title': 'İlan $id',
  'category': {'id': 'cat-1', 'code': 'WAITER', 'name': 'Garsonluk'},
  'type': 'ONE_TIME',
  'salaryType': 'DAILY',
  'salary': 800,
  'status': 'OPEN',
  'latitude': 39.9,
  'longitude': 32.8,
});

const _noResultsTitle = 'Sonuç bulunamadı';
const _noResultsHint = 'Farklı bir arama terimi deneyin';
const _retry = 'Tekrar Dene';

Future<void> pumpOverlay(
  WidgetTester tester, {
  required bool isSearching,
  bool isLoading = false,
  bool isRefreshing = false,
  String? errorMessage,
  bool isTruncated = false,
  List<Job> jobs = const [],
  VoidCallback? onRetry,
  ValueChanged<Job>? onJobTap,
  Brightness brightness = Brightness.light,
}) {
  return pumpInApp(
    tester,
    MapExploreOverlay(
      isSearching: isSearching,
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      errorMessage: errorMessage,
      isTruncated: isTruncated,
      jobs: jobs,
      onRetry: onRetry ?? () {},
      onJobTap: onJobTap ?? (_) {},
    ),
    brightness: brightness,
  );
}

void main() {
  // Kusur tam olarak buradaydı: durum kartının tamamı `!isSearching`'e bağlıydı
  // ve arama açıkken hata da kırpılma da ekrana hiç çıkmıyordu. Üç durum da
  // aramanın iki hâlinde birden sınanıyor; koşul geri gelirse `isSearching:
  // true` satırları kırmızıya döner.
  for (final isSearching in [true, false]) {
    final searchName = isSearching ? 'arama açıkken' : 'arama kapalıyken';

    testWidgets('$searchName hata mesajı ve Tekrar Dene çiziliyor', (
      tester,
    ) async {
      var retried = false;

      await pumpOverlay(
        tester,
        isSearching: isSearching,
        errorMessage: 'Sunucu hatası',
        onRetry: () => retried = true,
      );

      expect(find.text('Sunucu hatası'), findsOneWidget);
      expect(find.text(_retry), findsOneWidget);

      // Hata, boş sonuç metnine kılık değiştirmiyor.
      expect(find.text(_noResultsTitle), findsNothing);
      expect(find.text(_noResultsHint), findsNothing);

      await tester.tap(find.text(_retry));
      expect(retried, isTrue);
    });

    testWidgets('$searchName kırpılma uyarısı çiziliyor', (tester) async {
      await pumpOverlay(tester, isSearching: isSearching, isTruncated: true);

      expect(
        find.textContaining(
          '${MapExploreController.mapPageSize} ilandan fazlası',
        ),
        findsOneWidget,
      );
      expect(find.text(_noResultsTitle), findsNothing);
    });

    testWidgets('$searchName yükleniyor kartı çiziliyor', (tester) async {
      await pumpOverlay(tester, isSearching: isSearching, isLoading: true);

      expect(find.text('Bu alandaki ilanlar aranıyor...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_noResultsTitle), findsNothing);
    });
  }

  testWidgets('arama açıkken gerçekten boş sonuç boş sonuç metnini veriyor', (
    tester,
  ) async {
    await pumpOverlay(tester, isSearching: true);

    expect(find.text(_noResultsTitle), findsOneWidget);
    expect(find.text(_noResultsHint), findsOneWidget);
    expect(find.text(_retry), findsNothing);
  });

  testWidgets('arama kapalıyken boş sonuç kart çizmiyor', (tester) async {
    await pumpOverlay(tester, isSearching: false);

    // Harita boşken üstte kart yok: pin olmaması bir şey söylemiyor.
    // Boyutun sıfır olması "hiç çizilmedi"yi metin aramaktan daha sıkı bağlıyor.
    expect(find.text(_noResultsTitle), findsNothing);
    expect(tester.getSize(find.byType(MapExploreOverlay)), Size.zero);
  });

  testWidgets('kırpılma uyarısı arama sonucunun yerine değil üstüne geliyor', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      isSearching: true,
      isTruncated: true,
      jobs: [_job('a')],
    );

    expect(
      find.textContaining(
        '${MapExploreController.mapPageSize} ilandan fazlası',
      ),
      findsOneWidget,
    );
    expect(find.text('İlan a'), findsOneWidget);
  });

  testWidgets('hata varken eldeki sonuç listesi ekranda kalıyor', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      isSearching: true,
      errorMessage: 'Sunucu hatası',
      jobs: [_job('a')],
    );

    expect(find.text('Sunucu hatası'), findsOneWidget);
    expect(find.text('İlan a'), findsOneWidget);
  });

  testWidgets('sonuç satırına dokunmak ilanı geri veriyor', (tester) async {
    Job? tapped;

    await pumpOverlay(
      tester,
      isSearching: true,
      jobs: [_job('a')],
      onJobTap: (job) => tapped = job,
    );

    await tester.tap(find.text('İlan a'));
    expect(tapped?.id, 'a');
  });

  for (final brightness in Brightness.values) {
    final themeName = brightness == Brightness.dark ? 'koyu' : 'açık';

    testWidgets('$themeName temada bütün kartlar hatasız çiziliyor', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        isSearching: true,
        errorMessage: 'Sunucu hatası',
        jobs: [_job('a')],
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);

      await pumpOverlay(
        tester,
        isSearching: true,
        isTruncated: true,
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);

      await pumpOverlay(tester, isSearching: true, brightness: brightness);
      expect(tester.takeException(), isNull);
    });
  }

  group('sessiz yenileme', () {
    const refreshBar = ValueKey('map-refresh-bar');
    const loadingText = 'Bu alandaki ilanlar aranıyor...';

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} temada yenileme kart değil çizgi çizer', (
        tester,
      ) async {
        await pumpOverlay(
          tester,
          isSearching: false,
          isRefreshing: true,
          jobs: [_job('a')],
          brightness: brightness,
        );

        expect(find.byKey(refreshBar), findsOneWidget);
        expect(find.text(loadingText), findsNothing);
      });
    }

    testWidgets('ilk yüklemede kart çizilir, çizgi çizilmez', (tester) async {
      await pumpOverlay(
        tester,
        isSearching: false,
        isLoading: true,
        isRefreshing: true,
      );

      expect(find.text(loadingText), findsOneWidget);
      expect(find.byKey(refreshBar), findsNothing);
    });

    testWidgets('yenileme sırasında hata ve kırpılma uyarısı kaybolmaz', (
      tester,
    ) async {
      await pumpOverlay(
        tester,
        isSearching: false,
        isRefreshing: true,
        isTruncated: true,
        jobs: [_job('a')],
      );

      expect(find.byKey(refreshBar), findsOneWidget);
      expect(find.textContaining('ilandan fazlası'), findsOneWidget);
    });
  });
}
