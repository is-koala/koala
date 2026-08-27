import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/device_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('DeviceIdentity', () {
    test('üretilen kimlik backend deseniyle uyumlu', () async {
      final deviceId = await DeviceIdentity.fresh().deviceId();

      // Backend'in kabul ettiği desen: [A-Za-z0-9._:-]{8,128}
      expect(RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(deviceId), isTrue);
    });

    test('aynı kurulumda kimlik değişmiyor', () async {
      final identity = DeviceIdentity.fresh();

      expect(await identity.deviceId(), await identity.deviceId());
    });

    test('yeniden başlatmada diskteki kimlik okunuyor', () async {
      final first = await DeviceIdentity.fresh().deviceId();

      // Yeni örnek, bellek kopyası boş: değer diskten gelmeli.
      expect(await DeviceIdentity.fresh().deviceId(), first);
    });

    test('kimlik diske yazılıyor', () async {
      final deviceId = await DeviceIdentity.fresh().deviceId();
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getString('koala_device_id'), deviceId);
    });
  });
}
