import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/router/app_link_coordinator.dart';

void main() {
  test(
    'cold-start linki oturum okunana kadar bekletilir ve bir kez açılır',
    () {
      final coordinator = AppLinkCoordinator(
        appScheme: 'koala-staging',
        webHosts: const {'iskoala.com'},
      );
      final navigations = <String>[];

      coordinator.handle(
        Uri.parse('koala-staging://reset-password?token=reset-123'),
        sessionInitialized: false,
        navigate: navigations.add,
      );
      expect(navigations, isEmpty);

      coordinator.flush(sessionInitialized: true, navigate: navigations.add);
      coordinator.flush(sessionInitialized: true, navigate: navigations.add);

      expect(navigations, ['/reset-password?token=reset-123']);
    },
  );

  test('hazır oturumda gelen link beklemeden açılır', () {
    final coordinator = AppLinkCoordinator(
      appScheme: 'koala-staging',
      webHosts: const {'iskoala.com'},
    );
    final navigations = <String>[];

    coordinator.handle(
      Uri.parse('koala-staging://reset-password?token=reset-123'),
      sessionInitialized: true,
      navigate: navigations.add,
    );

    expect(navigations, ['/reset-password?token=reset-123']);
  });

  test('beklerken son gelen geçerli link açılır', () {
    final coordinator = AppLinkCoordinator(
      appScheme: 'koala-staging',
      webHosts: const {'iskoala.com'},
    );
    final navigations = <String>[];

    coordinator.handle(
      Uri.parse('koala-staging://reset-password?token=ilk'),
      sessionInitialized: false,
      navigate: navigations.add,
    );
    coordinator.handle(
      Uri.parse('koala-staging://reset-password?token=son'),
      sessionInitialized: false,
      navigate: navigations.add,
    );
    coordinator.flush(sessionInitialized: true, navigate: navigations.add);

    expect(navigations, ['/reset-password?token=son']);
  });

  test('geçersiz link bekleyen geçerli linki silmez', () {
    final coordinator = AppLinkCoordinator(
      appScheme: 'koala-staging',
      webHosts: const {'iskoala.com'},
    );
    final navigations = <String>[];

    coordinator.handle(
      Uri.parse('koala-staging://reset-password?token=reset-123'),
      sessionInitialized: false,
      navigate: navigations.add,
    );
    coordinator.handle(
      Uri.parse('https://api.iskoala.com/reset-password?token=attacker'),
      sessionInitialized: false,
      navigate: navigations.add,
    );
    coordinator.flush(sessionInitialized: true, navigate: navigations.add);

    expect(navigations, ['/reset-password?token=reset-123']);
  });
}
