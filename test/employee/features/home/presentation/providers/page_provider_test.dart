import 'package:flutter_test/flutter_test.dart';
import 'package:koala/employee/features/home/presentation/providers/page_provider.dart';

void main() {
  late PageProvider provider;
  late int notifications;

  setUp(() {
    provider = PageProvider();
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  group('explore görünümü', () {
    test('haritadan başlar', () {
      expect(provider.exploreViewType, ExploreViewType.map);
    });

    test('toggle harita ile liste arasında gidip gelir', () {
      provider.toggleExploreView();
      expect(provider.exploreViewType, ExploreViewType.list);

      provider.toggleExploreView();
      expect(provider.exploreViewType, ExploreViewType.map);
      expect(notifications, 2);
    });

    // setExploreViewType değer değişmediğinde dinleyicileri uyandırmıyor;
    // navbar'a aynı sekmeye arka arkaya basmak gereksiz rebuild yaratmasın.
    test('aynı değere set edilince bildirim atmaz', () {
      provider.setExploreViewType(ExploreViewType.map);
      expect(notifications, 0);

      provider.setExploreViewType(ExploreViewType.list);
      expect(notifications, 1);
    });

    // Buna karşılık setExploreViewToMap/List kısayolları koşulsuz bildiriyor.
    // Davranış farkı bilinçli değil ama mevcut; değişirse haberimiz olsun.
    test('setExploreViewToMap aynı değerde bile bildirir', () {
      provider.setExploreViewToMap();
      expect(provider.exploreViewType, ExploreViewType.map);
      expect(notifications, 1);
    });

    test('setExploreViewToList listeye geçirir', () {
      provider.setExploreViewToList();
      expect(provider.exploreViewType, ExploreViewType.list);
    });
  });

  group('jobs görünümü', () {
    test('home\'dan başlar', () {
      expect(provider.jobsViewType, JobsViewType.home);
    });

    test('toggle home ile saved arasında gidip gelir', () {
      provider.toggleJobsView();
      expect(provider.jobsViewType, JobsViewType.saved);

      provider.toggleJobsView();
      expect(provider.jobsViewType, JobsViewType.home);
    });

    test('aynı değere set edilince bildirim atmaz', () {
      provider.setJobsViewType(JobsViewType.home);
      expect(notifications, 0);
    });
  });

  test('iki görünüm birbirini etkilemez', () {
    provider.toggleExploreView();

    expect(provider.exploreViewType, ExploreViewType.list);
    expect(provider.jobsViewType, JobsViewType.home);
  });
}
