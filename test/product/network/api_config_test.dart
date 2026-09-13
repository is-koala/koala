import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/network/api_config.dart';

void main() {
  test(
    'dev iki simülatör platformunun açık yerel API adreslerini kullanır',
    () {
      expect(
        ApiConfig.resolveBaseUrl(
          flavor: 'dev',
          configuredUrl: 'http://localhost:8080/',
        ),
        'http://localhost:8080',
      );
      expect(
        ApiConfig.resolveBaseUrl(
          flavor: 'dev',
          configuredUrl: 'http://10.0.2.2:8080',
        ),
        'http://10.0.2.2:8080',
      );
    },
  );

  test('staging ve production yalnız açık HTTPS kök adresini kabul eder', () {
    for (final flavor in ['staging', 'production']) {
      expect(
        ApiConfig.resolveBaseUrl(
          flavor: flavor,
          configuredUrl: 'https://api.iskoala.com/',
        ),
        'https://api.iskoala.com',
      );
      expect(
        () => ApiConfig.resolveBaseUrl(
          flavor: flavor,
          configuredUrl: 'http://localhost:8080',
        ),
        throwsStateError,
      );
    }
  });

  test('ağ katmanı eksik derleme ayarını varsayılan API ile doldurmaz', () {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    if (appFlavor == null || configuredUrl.isEmpty) {
      expect(() => ApiConfig.baseUrl, throwsStateError);
    } else {
      expect(ApiConfig.baseUrl, configuredUrl);
    }
  });

  test(
    'staging bağlantısı kimlik bilgisi içeren veya şifresiz URL kabul etmez',
    () {
      for (final url in [
        'http://api.iskoala.com',
        'https://user:secret@api.iskoala.com',
        'https://api.iskoala.com?token=secret',
      ]) {
        expect(
          () => ApiConfig.resolveBaseUrl(flavor: 'staging', configuredUrl: url),
          throwsStateError,
        );
      }
    },
  );

  test('eksik API hedefi staging varsayımına dönüşmez', () {
    expect(
      () => ApiConfig.resolveBaseUrl(flavor: 'staging', configuredUrl: ''),
      throwsStateError,
    );
  });

  test('ortam seçilmeden internet API adresine bağlanılmaz', () {
    expect(
      () => ApiConfig.resolveBaseUrl(
        flavor: null,
        configuredUrl: 'https://api.iskoala.com',
      ),
      throwsStateError,
    );
  });

  test('web hostları virgülle ayrılmış yapılandırmadan okunur', () {
    expect(
      ApiConfig.resolveWebHosts(
        flavor: 'production',
        configuredHosts: 'iskoala.com, www.iskoala.com',
      ),
      {'iskoala.com', 'www.iskoala.com'},
    );
    expect(
      ApiConfig.resolveWebHosts(
        flavor: 'staging',
        configuredHosts: 'iskoala.com',
      ),
      {'iskoala.com'},
    );
  });

  test('web hostu yalnız çıplak küçük harfli alan adı olabilir', () {
    for (final hosts in [
      'https://iskoala.com',
      'iskoala.com/hesap-dogrula',
      'iskoala.com:443',
      'user@iskoala.com',
      'iskoala.com?token=x',
      'iskoala.com#fragment',
      'ISKOALA.com',
      'iskoala com',
    ]) {
      expect(
        () => ApiConfig.resolveWebHosts(
          flavor: 'production',
          configuredHosts: hosts,
        ),
        throwsStateError,
        reason: hosts,
      );
    }
  });

  test('staging ve production boş web host listesiyle açılmaz', () {
    for (final flavor in ['staging', 'production']) {
      expect(
        () => ApiConfig.resolveWebHosts(flavor: flavor, configuredHosts: ''),
        throwsStateError,
        reason: flavor,
      );
    }
    expect(
      ApiConfig.resolveWebHosts(flavor: 'dev', configuredHosts: ''),
      isEmpty,
    );
    expect(
      () => ApiConfig.resolveWebHosts(
        flavor: null,
        configuredHosts: 'iskoala.com',
      ),
      throwsStateError,
    );
  });

  test('derleme yapılandırması web hostlarını da doğrular', () {
    const configuredHosts = String.fromEnvironment('WEB_HOSTS');
    if (appFlavor == null) {
      expect(() => ApiConfig.webHosts, throwsStateError);
    } else {
      expect(
        ApiConfig.webHosts,
        ApiConfig.resolveWebHosts(
          flavor: appFlavor,
          configuredHosts: configuredHosts,
        ),
      );
    }
  });

  test('her flavor yalnız kendi native bağlantı şemasını kullanır', () {
    expect(ApiConfig.resolveAppUrlScheme(flavor: 'dev'), 'koala-dev');
    expect(ApiConfig.resolveAppUrlScheme(flavor: 'staging'), 'koala-staging');
    expect(ApiConfig.resolveAppUrlScheme(flavor: 'production'), 'koala');
    expect(() => ApiConfig.resolveAppUrlScheme(flavor: null), throwsStateError);
  });
}
