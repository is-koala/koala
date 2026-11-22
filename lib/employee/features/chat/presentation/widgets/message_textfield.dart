import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class MessageTextField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSendMessage;

  /// Aynı mesaj iki kez gönderilmesin.
  final bool isSending;

  final ValueChanged<String>? onChanged;
  final VoidCallback? onAddPressed;

  const MessageTextField({
    super.key,
    required this.controller,
    required this.onSendMessage,
    this.isSending = false,
    this.onChanged,
    this.onAddPressed,
  });

  static const double _fieldHeight = 52;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: AppPadding.iconButton,
        decoration: BoxDecoration(color: context.backgroundColor),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: _fieldHeight,
                decoration: BoxDecoration(
                  color: context.tileColor,
                  borderRadius: AppRadius.stadiumCircular,
                ),
                child: TextFormField(
                  controller: controller,
                  onChanged: onChanged,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.center,
                  style: context.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Mesaj yazın...',
                    hintStyle: context.textTheme.bodyLarge?.copyWith(
                      color: context.textTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spaceLarge,
                    ),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(AppSizes.spaceTiny),
                      decoration: BoxDecoration(
                        color: context.accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send,
                          color: context.onAccentColor,
                          size: AppSizes.iconSmall,
                        ),
                        onPressed: isSending ? null : onSendMessage,
                      ),
                    ),
                  ),
                  onFieldSubmitted: (_) => isSending ? null : onSendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
