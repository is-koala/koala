import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/keyboard_done_bar.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Testte simüle edilen klavyenin mantıksal yüksekliği.
///
/// 800×600'lük test penceresinin yarısı: gerçek bir telefonda klavye de
/// ekranın kabaca yarısını kaplıyor, o yüzden alt düğmenin "arkada kalması"
/// aynı oranla yeniden üretilebiliyor.
const double keyboardHeight = 300;

/// Klavyeyi simüle eder: alt `viewInsets`'i [height] kadar açar ve test
/// bitince sıfırlar. `MediaQuery` bunu gerçek klavye gibi görür; `Scaffold`
/// gövdeyi küçültür, `FormPageBody` ve `ButtonNavbar` paylarını büyütür.
///
/// Yardımcılar `pumpAndSettle` yerine tek `pump` kullanıyor: geri sayım gibi
/// sürekli zamanlayıcı taşıyan ekranlarda `pumpAndSettle` hiç dönmüyor,
/// odak ve kaydırma ise tek karede yerine oturuyor.
Future<void> showKeyboard(
  WidgetTester tester, {
  double height = keyboardHeight,
}) async {
  tester.view.viewInsets = FakeViewPadding(
    bottom: height * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetViewInsets);
  await tester.pump();
}

/// Ekranın mantıksal yüksekliği; klavyenin üst kenarı buradan
/// [keyboardHeight] çıkarılarak bulunuyor.
double screenHeightOf(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

/// Klavyenin (ve iOS'ta görünürse "Bitti" şeridinin) üst kenarı: içeriğin
/// bu çizginin üstünde kalması gerekiyor.
double keyboardTopOf(WidgetTester tester, {double height = keyboardHeight}) {
  final doneBar = find.byType(KeyboardDoneBar);
  if (doneBar.evaluate().isNotEmpty) return tester.getRect(doneBar).top;
  return screenHeightOf(tester) - height;
}

/// Düğmenin klavyenin (ve şeridin) üstünde, ekranda ve dokunulabilir
/// olduğunu doğrular; gövdenin içindeyse önce oraya kaydırır.
/// `hitTestable` düğmenin merkezine giden dokunuşun ona ulaştığını
/// söylüyor: şeridin arkasında kalan bir düğme burada düşer.
Future<void> expectAboveKeyboard(
  WidgetTester tester,
  Finder cta, {
  double height = keyboardHeight,
}) async {
  await tester.ensureVisible(cta);
  await tester.pump();

  final rect = tester.getRect(cta);
  final keyboardTop = keyboardTopOf(tester, height: height);
  expect(
    rect.bottom,
    lessThanOrEqualTo(keyboardTop),
    reason:
        'düğme klavyenin arkasında kaldı (alt kenar ${rect.bottom}, '
        'klavye üstü $keyboardTop)',
  );
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(cta.hitTestable(), findsOneWidget, reason: 'düğmeye dokunulamıyor');
}

/// Alanı kaydırıp odaklar ve `EditableText`'in imleci görünür alana
/// taşımasını (100 ms) ve odakla açılan bir kartın büyümesini (250 ms)
/// bekler.
Future<void> focusField(WidgetTester tester, Finder field) async {
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.tap(field);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Odaklı alanın klavyenin (ve şeridin) üstünde kaldığını doğrular.
Future<void> expectFocusedFieldAboveKeyboard(
  WidgetTester tester,
  Finder field, {
  double height = keyboardHeight,
}) async {
  await focusField(tester, field);
  expect(anyFieldFocused(tester), isTrue, reason: 'alan odaklanamadı');

  final bottom = tester.getRect(field).bottom;
  final keyboardTop = keyboardTopOf(tester, height: height);
  expect(
    bottom,
    lessThanOrEqualTo(keyboardTop),
    reason:
        'odaklı alan klavyenin arkasında kaldı (alt kenar $bottom, '
        'klavye üstü $keyboardTop)',
  );
}

/// `Scaffold.bottomNavigationBar`'daki [ButtonNavbar]'ın düğmesi. Çubuğun
/// kendisi klavye payıyla ekranın dibine kadar uzuyor; klavyenin üstünde
/// kalması gereken şey düğme.
Finder findBottomBarButton() => find.descendant(
  of: find.byType(ButtonNavbar),
  matching: find.byType(MyButton),
);

/// Formun boş alanına dokunur: [FormPageBody]'nin sol üst köşesi, içeriğin
/// kenar payına düşer ve hiçbir alanı hedeflemez.
Future<void> tapEmptyFormArea(WidgetTester tester) async {
  final body = find.byType(FormPageBody).first;
  await tester.tapAt(tester.getTopLeft(body) + const Offset(4, 4));
  await tester.pump();
}

/// Herhangi bir metin alanının odağı var mı.
bool anyFieldFocused(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .any((field) => field.focusNode.hasFocus);

/// Alanı odaklar, boş alana dokunur ve odağın düştüğünü doğrular.
///
/// `unfocus` odağı en yakın `FocusScope`'a bırakır, `primaryFocus` hiç
/// `null` olmaz; o yüzden ölçülen şey alanın odağı.
Future<void> expectTapOutsideDropsFocus(
  WidgetTester tester,
  Finder field,
) async {
  await focusField(tester, field);
  expect(anyFieldFocused(tester), isTrue, reason: 'alan odaklanamadı');

  await tapEmptyFormArea(tester);

  expect(anyFieldFocused(tester), isFalse, reason: 'odak düşmedi');
}

/// iOS: sayısal alanı odaklar ve "Bitti" şeridiyle birlikte yerleşimi
/// doğrular — şerit çıkmış, odaklı alan şeridin üstünde, [cta] şeridin
/// üstünde ve dokunulabilir. CTA'ya dokunup etkisini ölçmek çağırana kalıyor.
Future<void> expectDoneBarLayout(
  WidgetTester tester, {
  required Finder numericField,
  required Finder cta,
}) async {
  await showKeyboard(tester);
  await expectFocusedFieldAboveKeyboard(tester, numericField);
  expect(
    find.byType(KeyboardDoneBar),
    findsOneWidget,
    reason: 'Bitti şeridi çizilmedi',
  );
  await expectAboveKeyboard(tester, cta);
}

/// "Bitti"ye dokunur: odak düşer, şerit kalkar.
Future<void> tapDoneBar(WidgetTester tester) async {
  await tester.tap(find.text(KeyboardDoneBar.label));
  await tester.pump();
  expect(find.byType(KeyboardDoneBar), findsNothing);
  expect(anyFieldFocused(tester), isFalse);
}
