import 'package:material_ui/material_ui.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/message.dart';
import 'package:koala/employee/features/chat/models/message_sender.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/employee/features/chat/presentation/widgets/message_seen_sheet.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/report.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/report_sheet.dart';

enum _MessageAction { report }

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isNextSameSender;

  /// Kendi mesajında ve ikilide `null`.
  final MessageSender? sender;

  /// Boşsa satır çizilmez.
  final List<ChatParticipant> seenBy;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isNextSameSender,
    this.sender,
    this.seenBy = const [],
  });

  static const double _maxWidthRatio = 0.75;

  /// Kimin yazdığı hizadan anlaşılsın.
  static const double _oppositeMargin = 48;

  static const double _bubbleRadius = 18;

  static const double _senderAvatarSize = 28;
  static const double _senderAvatarRadius = 10;

  static const double _metaAlpha = 0.7;

  static String seenLabel(int count) => '$count kişi gördü';

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final maxWidth = MediaQuery.sizeOf(context).width * _maxWidthRatio;
    final foreground = isMe ? context.onAccentColor : context.textPrimary;
    final sender = this.sender;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: AppPadding.messageBubble,
      decoration: BoxDecoration(
        color: isMe ? context.accentColor : context.tileColor,
        borderRadius: BorderRadius.circular(_bubbleRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sender != null) ...[
            _senderLine(context, sender),
            const SizedBox(height: AppSizes.spaceTiny),
          ],
          Text(
            message.body,
            style: context.textTheme.bodyLarge?.copyWith(color: foreground),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            message.timeString,
            style: context.textTheme.labelMedium?.copyWith(
              color: foreground.withValues(alpha: _metaAlpha),
            ),
          ),
          if (seenBy.isNotEmpty) _seenLine(context, foreground),
        ],
      ),
    );

    return GestureDetector(
      // Kendi mesajını şikayet anlamsız; menü yalnız karşı tarafın mesajında.
      onLongPress: isMe ? null : () => _openMenu(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: isNextSameSender ? AppSizes.spaceTiny : AppSizes.space,
            left: isMe ? _oppositeMargin : 0,
            right: isMe ? 0 : _oppositeMargin,
          ),
          child: sender == null
              ? bubble
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ChatAvatar(
                      avatarUrl: sender.avatarUrl,
                      fallbackText: sender.initials,
                      size: _senderAvatarSize,
                      borderRadius: _senderAvatarRadius,
                    ),
                    const SizedBox(width: AppSizes.spaceSmall),
                    Flexible(child: bubble),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _senderLine(BuildContext context, MessageSender sender) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            sender.name,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.accentColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (sender.left) ...[
          const SizedBox(width: AppSizes.spaceTiny),
          Text(
            ChatParticipant.leftLabel,
            style: context.textTheme.labelSmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _seenLine(BuildContext context, Color foreground) {
    final color = foreground.withValues(alpha: _metaAlpha);
    final label = seenLabel(seenBy.length);

    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spaceTiny),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => MessageSeenSheet.show(context, readers: seenBy),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(AppIcons.eyeOpen, size: AppSizes.iconSmall, color: color),
              const SizedBox(width: AppSizes.spaceTiny),
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Menü balonun üstünde açılır ki hangi mesaj olduğu belli olsun.
  Future<void> _openMenu(BuildContext context) async {
    final bubble = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (bubble == null || overlay == null) return;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        bubble.localToGlobal(Offset.zero, ancestor: overlay),
        bubble.localToGlobal(
          bubble.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<_MessageAction>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(value: _MessageAction.report, child: Text('Şikayet Et')),
      ],
    );

    if (action == null || !context.mounted) return;

    await ReportSheet.show(
      context,
      ReportTarget.message(messageId: message.id),
    );
  }
}
