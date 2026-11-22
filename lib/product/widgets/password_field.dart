import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_textfield.dart';

/// Göster/gizle düğmeli parola alanı. Tek yerde ki ikonun anlamı her ekranda
/// aynı kalsın: **gizliyken kapalı göz, görünürken açık göz**.
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

  final bool isHidden;

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
