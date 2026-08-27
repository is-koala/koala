import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isNextSameSender;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isNextSameSender,
  });

  /// Balonun kaplayabileceği en fazla genişlik. Karşı tarafın balonuyla
  /// aynı hizada durmaması için ekranın tamamını kaplamıyor.
  static const double _maxWidthRatio = 0.75;

  /// Balonun karşı kenarında bırakılan boşluk; kimin yazdığı hizadan
  /// anlaşılsın diye.
  static const double _oppositeMargin = 48;

  /// Balonun köşe yuvarlaklığı. Sabit listelerdeki değerlerden bağımsız:
  /// sohbet balonuna özgü bir ölçü.
  static const double _bubbleRadius = 18;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final maxWidth = MediaQuery.sizeOf(context).width * _maxWidthRatio;
    final foreground = isMe ? context.onAccentColor : context.textPrimary;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.only(
          // Aynı kişinin peş peşe mesajları birbirine yakın dursun.
          bottom: isNextSameSender ? AppSizes.spaceTiny : AppSizes.space,
          left: isMe ? _oppositeMargin : 0,
          right: isMe ? 0 : _oppositeMargin,
        ),
        padding: AppPadding.messageBubble,
        decoration: BoxDecoration(
          color: isMe ? context.accentColor : context.tileColor,
          borderRadius: BorderRadius.circular(_bubbleRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.body,
              style: context.textTheme.bodyLarge?.copyWith(color: foreground),
            ),
            const SizedBox(height: AppSizes.spaceTiny),
            Text(
              message.timeString,
              style: context.textTheme.labelMedium?.copyWith(
                color: foreground.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
