import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/theme/theme.dart';

void main() {
  group('yeşil zeminin üstündeki içerik', () {
    // Koyu temada bir dönem sayfa zeminine (siyaha) bağlıydı. Yeşil butonun
    // yazısı, sohbet balonu, seçili filtre ve onay kutusunun tiki -- yeşilin
    // üstündeki her şey -- koyu temada siyah çıkıyordu.
    test('onPrimary iki temada da beyaz', () {
      expect(lightTheme.colorScheme.onPrimary, AppColors.onAccent);
      expect(darkTheme.colorScheme.onPrimary, AppColors.onAccent);
    });

    test('doygun renkli diğer zeminler de aynı davranıyor', () {
      for (final scheme in [lightTheme.colorScheme, darkTheme.colorScheme]) {
        expect(scheme.onSecondary, AppColors.onAccent);
        expect(scheme.onError, AppColors.onAccent);
      }
    });
  });

  test('vurgu rengi temadan bağımsız marka yeşili', () {
    expect(lightTheme.colorScheme.primary, AppColors.primaryColor);
    expect(darkTheme.colorScheme.primary, AppColors.primaryColor);
  });
}
