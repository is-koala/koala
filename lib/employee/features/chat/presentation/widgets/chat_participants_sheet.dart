import 'package:flutter/material.dart';
import 'package:koala/employee/features/chat/models/chat_participant.dart';
import 'package:koala/employee/features/chat/models/conversation.dart';
import 'package:koala/employee/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/widgets/app_bottom_sheet.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/messaging_gate_note.dart';

/// Grup sohbetinin katılımcıları; başlığa dokununca açılıyor.
///
/// İlan başlığı, katılımcı sayısı ve kişi başına ad, rol, katılma tarihi.
/// Ayrılanlar listenin sonunda ve gri; oturum sahibi "Siz" etiketiyle.
/// Sohbet kapandıysa üstte not var. İki kabuk aynı sheet'i çiziyor; profil
/// bağlantısı [onOpenProfile] ile dışarıdan geliyor, çünkü başkasının
/// profilini açan rota bugün yalnız işveren kabuğunda var
/// (`/business/user-profile`).
class ChatParticipantsSheet extends StatelessWidget {
  const ChatParticipantsSheet({
    super.key,
    required this.chat,
    required this.participants,
    this.currentUserId,
    this.onOpenProfile,
  });

  final Conversation chat;

  /// Denetleyicideki güncel liste; `chat.participants` liste ekranından
  /// kalan anlık görüntü olabilir.
  final List<ChatParticipant> participants;

  /// Oturum sahibi; satırı "Siz" etiketi alıyor ve profil bağlantısı yok.
  final String? currentUserId;

  /// Bir katılımcının profilini açar; `null` ise satırlar dokunulmuyor.
  final ValueChanged<ChatParticipant>? onOpenProfile;

  static const String title = 'Katılımcılar';
  static const String closedNote =
      'Bu sohbet kapandı; yeni mesaj gönderilemiyor.';
  static const String emptyNote = 'Katılımcı bilgisi henüz yok.';
  static const String youTag = 'Siz';
  static const String leftTag = 'Ayrıldı';

  /// Avatar ölçüleri; başlıktakiyle aynı.
  static const double _avatarSize = 40;
  static const double _avatarRadius = 14;

  /// Ayrılan katılımcının avatarı soluk.
  static const double _leftOpacity = 0.5;

  /// Listenin kaplayabileceği en fazla yükseklik oranı.
  static const double _maxHeightRatio = 0.6;

  static Future<void> show(
    BuildContext context, {
    required Conversation chat,
    required List<ChatParticipant> participants,
    String? currentUserId,
    ValueChanged<ChatParticipant>? onOpenProfile,
  }) {
    return AppBottomSheet.show<void>(
      context,
      builder: (_) => ChatParticipantsSheet(
        chat: chat,
        participants: participants,
        currentUserId: currentUserId,
        onOpenProfile: onOpenProfile,
      ),
    );
  }

  /// Aktifler önce, ayrılanlar sonda; kendi içlerinde sunucu sırası.
  List<ChatParticipant> get _ordered => [
    ...participants.where((participant) => !participant.left),
    ...participants.where((participant) => participant.left),
  ];

  @override
  Widget build(BuildContext context) {
    final ordered = _ordered;

    return AppBottomSheet(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat.jobTitle,
            style: context.textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSizes.smallGap),
          Text(
            '${ordered.length} katılımcı',
            style: context.textTheme.labelMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          if (chat.closed) ...[
            const SizedBox(height: AppSizes.space),
            const MessagingGateNote(message: closedNote),
          ],
          const SizedBox(height: AppSizes.spaceMedium),
          if (ordered.isEmpty)
            Text(
              emptyNote,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textTertiary,
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: context.dynamicHeight(_maxHeightRatio),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: ordered.length,
                  itemBuilder: (_, index) => _row(context, ordered[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ChatParticipant participant) {
    final isMe = participant.id == currentUserId;
    final onOpenProfile = this.onOpenProfile;
    final canOpen = onOpenProfile != null && !isMe;
    final nameColor = participant.left
        ? context.textTertiary
        : context.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      // Sheet'in zemini `DecoratedBox`; `ListTile` mürekkebini onun altına
      // basıyor. Dokunulabilir satır bu yüzden Material + InkWell + Padding.
      child: Material(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          borderRadius: AppRadius.innerCircular,
          onTap: canOpen
              ? () {
                  // Sheet kapanıp profil açılıyor; dönüşte sohbet görünsün.
                  Navigator.pop(context);
                  onOpenProfile(participant);
                }
              : null,
          child: Padding(
            padding: AppPadding.tile,
            child: Row(
              children: [
                Opacity(
                  opacity: participant.left ? _leftOpacity : 1,
                  child: ChatAvatar(
                    avatarUrl: participant.profilePictureUrl,
                    fallbackText: participant.initials,
                    size: _avatarSize,
                    borderRadius: _avatarRadius,
                  ),
                ),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              participant.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: nameColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: AppSizes.spaceTiny),
                            _tag(context, youTag, context.accentColor),
                          ],
                          if (participant.left) ...[
                            const SizedBox(width: AppSizes.spaceTiny),
                            _tag(context, leftTag, context.textTertiary),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSizes.smallGap),
                      _details(context, participant),
                    ],
                  ),
                ),
                if (canOpen) ...[
                  const SizedBox(width: AppSizes.spaceSmall),
                  AppIcon(
                    AppIcons.arrowRight,
                    size: AppSizes.iconSmall,
                    color: context.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rol etiketi ve katılma tarihi; eski sunucuda ikisi de boş.
  Widget _details(BuildContext context, ChatParticipant participant) {
    final joinedAt = participant.joinedAt;
    final parts = <String>[
      if (participant.role.label.isNotEmpty) participant.role.label,
      if (joinedAt != null) 'Katılım: ${joinedAt.toLocal().asShortDate}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      style: context.textTheme.labelMedium?.copyWith(
        color: participant.left ? context.textTertiary : context.textSecondary,
      ),
    );
  }

  Widget _tag(BuildContext context, String label, Color color) {
    return Container(
      padding: AppPadding.badge,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.surfaceTintAlpha),
        borderRadius: AppRadius.smallCircular,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
