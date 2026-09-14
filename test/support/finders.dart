import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// Belirli bir `AppIcons` adını çizen [AppIcon]'u bulur.
///
/// `find.byIcon` işe yaramıyor: o yalnız Material'ın `Icon`'unu ve onun
/// `IconData`'sını tanıyor, `AppIcon` ise ikonu SVG olarak çiziyor. Bir ikon
/// `Icons.*`'tan `AppIcons.*`'a taşındığında testteki `find.byIcon` sessizce
/// hiçbir şey bulmaz hâle gelmesin diye arama adın kendisi üzerinden yapılıyor.
Finder findAppIcon(AppIconData name) => find.byWidgetPredicate(
  (widget) => widget is AppIcon && widget.name == name,
  description: 'AppIcon("$name")',
);

/// Etiketi [label] olan `TextField`'ı bulur (`MyTextfield` de bunu çiziyor).
///
/// Etiket `InputDecoration.labelText`'te; `find.text` onu bulamıyor çünkü
/// etiket ayrı bir `Text` widget'ı değil, dekorasyonun parçası.
Finder findFieldLabelled(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  description: 'TextField("$label")',
);
