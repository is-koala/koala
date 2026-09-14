import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';

/// Grupta kendi mesajını görenlerin listesi: "3 kişi gördü" etiketine
/// dokununca açılıyor.
///
/// Satırlar dokunulmuyor; kişi başına ad ve okuma anı yazıyor. Liste
/// `participants[].lastReadAt >= sentAt` ile istemcide hesaplanıyor
/// (is-koala/koala-backend#281 `readBy` göndermiyor).
class MessageSeenSheet extends StatelessWidget {
  const MessageSeenSheet({super.key, required this.readers});

  final List<ChatParticipant> readers;

  static const String title = 'Görenler';

  /// Avatar ölçüleri; başlıktakiyle aynı.
  static const double _avatarSize = 40;
  static const double _avatarRadius = 14;

  /// Listenin kaplayabileceği en fazla yükseklik oranı.
  static const double _maxHeightRatio = 0.6;

  static Future<void> show(
    BuildContext context, {
    required List<ChatParticipant> readers,
  }) {
    return AppBottomSheet.show<void>(
      context,
      builder: (_) => MessageSeenSheet(readers: readers),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title,
      child: Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: context.dynamicHeight(_maxHeightRatio),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: readers.length,
            itemBuilder: (_, index) => _row(context, readers[index]),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, ChatParticipant reader) {
    final readAt = reader.lastReadAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.space),
      child: Row(
        children: [
          ChatAvatar(
            avatarUrl: reader.profilePictureUrl,
            fallbackText: reader.initials,
            size: _avatarSize,
            borderRadius: _avatarRadius,
          ),
          const SizedBox(width: AppSizes.space),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reader.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (readAt != null)
                  Text(
                    readAt.toLocal().asShortDateTime,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
