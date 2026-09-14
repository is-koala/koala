import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/account/models/notification_preference.dart';
import 'package:koala/product/features/account/services/notification_preference_service.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/empty_state.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/settings_hint.dart';

part 'notification_preferences_pagemodel.dart';

/// Bildirim tercihleri: kategori × kanal anahtar tablosu.
///
/// Hesap kullanıcıya ait; iki uygulamanın ayarları da aynı ekranı açıyor.
/// Her anahtar kendi başına kaydediliyor (`PUT` yalnız o kombinasyonu
/// taşıyor): ayrı bir "Kaydet" düğmesi, yedi kategoride hangi anahtarın
/// değiştiğini kullanıcının aklında tutmasını isterdi.
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key, this.service});

  /// Testlerde sahte sunucuya bağlı örnek geçilebilsin diye.
  final NotificationPreferenceService? service;

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends NotificationPreferencesPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: const MyAppbar(title: 'Bildirim Tercihleri'),
      body: _body(),
    );
  }

  Widget _body() {
    if (isLoading && groups.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = errorMessage;
    if (groups.isEmpty && error != null) {
      return EmptyState(
        icon: AppIcons.alert,
        title: 'Tercihler açılamadı',
        description: error,
        action: TextButton(onPressed: load, child: const Text('Tekrar Dene')),
      );
    }

    return RefreshIndicator(
      onRefresh: () => load(silent: true),
      child: groups.isEmpty
          ? const EmptyState(
              icon: AppIcons.notification,
              title: 'Tercih bulunamadı',
              description:
                  'Sunucu bu hesap için bildirim kategorisi '
                  'göndermedi.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppPadding.primary,
                AppSizes.spaceSmall,
                AppPadding.primary,
                AppSizes.navBarClearance,
              ),
              itemCount: groups.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSizes.spaceMedium),
              itemBuilder: (context, index) => _groupCard(groups[index]),
            ),
    );
  }

  Widget _groupCard(NotificationPreferenceGroup group) {
    final hint = group.hint;

    return Container(
      key: ValueKey('preference-group-${group.category}'),
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppPadding.infoTile,
            child: Text(
              group.title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final row in group.channels) _channelRow(row),
          if (hint != null)
            SettingsHint(
              hint,
              padding: const EdgeInsets.fromLTRB(
                AppPadding.primary,
                AppSizes.spaceTiny,
                AppPadding.primary,
                AppSizes.space,
              ),
            ),
        ],
      ),
    );
  }

  /// Tek bir kanal satırı. Kilitli satırın anahtarı devre dışı: sunucu bu
  /// kombinasyonu kapatmayı reddediyor, kullanıcıya deneyip hata görmek
  /// yerine baştan söyleniyor.
  Widget _channelRow(NotificationPreference row) {
    final isBusy = isSaving(row);
    final canToggle = row.editable && !isBusy;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canToggle ? () => toggle(row) : null,
        child: Padding(
          padding: AppPadding.tile,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  NotificationChannelLabels.of(row.channel),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: row.editable
                        ? context.textPrimary
                        : context.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.space),
              Switch.adaptive(
                key: ValueKey('preference-${row.category}-${row.channel}'),
                value: row.enabled,
                onChanged: canToggle ? (_) => toggle(row) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
