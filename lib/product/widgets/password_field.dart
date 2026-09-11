import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Göster/gizle düğmesi taşıyan parola alanı.
///
/// Aynı beşli ([MyTextfield] + `isObscureText` + `showSuffixIcon` +
/// `visiblePassword` klavyesi + göz ikonu) giriş, parola oluşturma ve parola
/// değiştirme ekranlarında üç kez elle kuruluyordu. Tek yerde durmasının asıl
/// kazancı ikonun anlamı: **gizliyken kapalı göz, görünürken açık göz**.
/// Kopyaların ikisi aynı bayrağı zıt adlarla taşıyordu, yani ikonun bir
/// ekranda ters dönmesi bir sonraki düzenlemeye kalmıştı.
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.labelText,
    required this.controller,
    this.isHidden = true,
    required this.onToggle,
    this.onChanged,
  });

  final String labelText;
  final TextEditingController controller;

  /// Metin gizli mi. `true` iken alan noktalarla yazıyor ve ikon kapalı göz
  /// oluyor; ikonu çeviren state sayfada kalıyor.
  final bool isHidden;

  /// Göz ikonuna basıldığında çağrılır.
  final VoidCallback onToggle;

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MyTextfield(
      labelText: labelText,
      controller: controller,
      isObscureText: isHidden,
      showSuffixIcon: true,
      keyboardType: TextInputType.visiblePassword,
      onChanged: onChanged,
      suffixIcon: IconButton(
        icon: AppIcon(
          isHidden ? AppIcons.eyeClosed : AppIcons.eyeOpen,
          color: context.textSecondary,
        ),
        onPressed: onToggle,
      ),
    );
  }
}
