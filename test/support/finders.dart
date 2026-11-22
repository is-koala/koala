import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koala/product/constants/app_icon_data.dart';
import 'package:koala/product/widgets/app_icon.dart';

/// [AppIcon]'u adıyla bulur; `find.byIcon` SVG ikonu görmez ve taşınan ikonda
/// sessizce hiçbir şey bulmazdı.
Finder findAppIcon(AppIconData name) => find.byWidgetPredicate(
  (widget) => widget is AppIcon && widget.name == name,
  description: 'AppIcon("$name")',
);

/// Etiket dekorasyonun parçası; `find.text` bulamıyor.
Finder findFieldLabelled(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  description: 'TextField("$label")',
);
