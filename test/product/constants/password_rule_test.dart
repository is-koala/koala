import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/password_rule.dart';

void main() {
  group('PasswordRule.isSatisfiedBy', () {
    test('sekiz karakter, büyük/küçük harf ve rakam varsa geçiyor', () {
      expect(PasswordRule.isSatisfiedBy('KoalaDemo1'), isTrue);
    });

    test('sekiz karakterden kısa parola geçmiyor', () {
      expect(PasswordRule.isSatisfiedBy('Koala1a'), isFalse);
    });

    test('büyük harf yoksa geçmiyor', () {
      expect(PasswordRule.isSatisfiedBy('koalademo1'), isFalse);
    });

    test('küçük harf yoksa geçmiyor', () {
      expect(PasswordRule.isSatisfiedBy('KOALADEMO1'), isFalse);
    });

    test('rakam yoksa geçmiyor', () {
      expect(PasswordRule.isSatisfiedBy('KoalaDemoo'), isFalse);
    });

    test('boş parola geçmiyor', () {
      expect(PasswordRule.isSatisfiedBy(''), isFalse);
    });
  });

  group('PasswordRule.requirement', () {
    // Metnin kendisini burada tekrar yazmak tautolojik olurdu; anlamlı olan,
    // metnin kuralla tutarlı kalması: kullanıcıya söylenen alt sınır
    // gerçekten uygulanan alt sınır olmalı.
    test('kullanıcıya söylenen alt sınır uygulanan sınırla aynı', () {
      expect(PasswordRule.requirement, contains('${PasswordRule.minLength}'));
      expect(PasswordRule.isSatisfiedBy('Koala1a'), isFalse);
      expect(PasswordRule.isSatisfiedBy('Koala12a'), isTrue);
    });
  });
}
