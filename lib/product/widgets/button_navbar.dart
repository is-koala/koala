import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/keyboard_insets.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Sayfanın altına sabitlenen tek butonluk çubuk.
///
/// `Scaffold` alt çubuğu klavyeyi hesaba katmadığı için alt pay klavye kadar
/// ([KeyboardInsets], iOS "Bitti" şeridi dâhil) büyütülüyor. Klavye açıkken
/// sistem güvenli alanı sıfır geliyor, paylar üst üste binmiyor.
class ButtonNavbar extends StatelessWidget {
  const ButtonNavbar({
    super.key,
    required this.onPressed,
    required this.title,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String title;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return KeyboardInsetsBuilder(
      builder: (context, keyboard) => Container(
        padding: AppPadding.bottomBar.copyWith(
          bottom:
              context.padding.bottom + keyboard + AppPadding.bottomBar.bottom,
        ),
        decoration: BoxDecoration(
          color: context.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.barShadow,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: MyButton(
          onPressed: onPressed,
          title: title,
          isLoading: isLoading,
        ),
      ),
    );
  }
}
