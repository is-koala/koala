import 'package:flutter/material.dart';
import 'package:koala/employee/features/profile/presentation/providers/availability_provider.dart';
import 'package:koala/employee/features/profile/presentation/providers/user_provider.dart';
import 'package:koala/employee/features/profile/presentation/widgets/availability_day_editor.dart';
import 'package:koala/employee/features/profile/presentation/widgets/availability_exception_sheet.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/models/availability_day.dart';
import 'package:koala/product/models/availability_exception.dart';
import 'package:koala/product/models/availability_slot.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/app_toast.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:provider/provider.dart';

part 'availability_pagemodel.dart';

/// İş arayanın haftalık müsaitlik şablonu ve tarih istisnaları.
class AvailabilityPage extends StatefulWidget {
  const AvailabilityPage({super.key});

  @override
  State<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends AvailabilityPagemodel {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AvailabilityProvider>();
    final userProvider = context.watch<UserProvider>();
    final userId = userProvider.user?.id;
    final isInitialized = userId != null && provider.isLoadedFor(userId);

    return Scaffold(
      appBar: MyAppbar(title: 'Müsaitliğim', isLarge: true),
      body: isInitialized
          ? _content(provider)
          : _initializationState(userProvider, provider),
    );
  }

  Widget _initializationState(
    UserProvider userProvider,
    AvailabilityProvider availabilityProvider,
  ) {
    final message = userProvider.user == null
        ? userProvider.errorMessage
        : availabilityProvider.errorMessage;
    if (message != null) return _errorState(message);

    return const Center(child: CircularProgressIndicator());
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(
              AppIcons.alert,
              size: AppSizes.iconHuge,
              color: context.dividerColor,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            OutlinedButton(
              onPressed: _reload,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(AvailabilityProvider provider) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppPadding.primaryAll,
        children: [
          Text(
            'Haftalık Şablon',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.spaceTiny),
          Text(
            'Düzenli olarak çalışabileceğin saatleri ekle.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          ...AvailabilityDay.values.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
              child: AvailabilityDayEditor(
                day: day,
                slots: provider.slotsForDay(day),
                onAdd: () => _addSlot(day),
                onRemove: (index) => _removeSlot(day, index),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          MyButton(
            onPressed: _saveWeekly,
            title: 'Haftalık Şablonu Kaydet',
            isLoading: provider.isSaving,
          ),
          const SizedBox(height: AppSizes.sectionSpace),
          _exceptionHeader(),
          const SizedBox(height: AppSizes.spaceSmall),
          if (provider.availability?.exceptions.isEmpty ?? true)
            Text(
              'Henüz tarih istisnası eklemedin.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textTertiary,
              ),
            )
          else
            ...provider.availability!.exceptions.map(_exceptionCard),
          const SizedBox(height: AppSizes.sectionSpace),
        ],
      ),
    );
  }

  Widget _exceptionHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tarih İstisnaları',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.spaceTiny),
              Text(
                'Belirli bir gün için haftalık planını geçersiz kıl.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tarih istisnası ekle',
          onPressed: () => _editException(),
          icon: AppIcon(AppIcons.plus, color: context.accentColor),
        ),
      ],
    );
  }

  Widget _exceptionCard(AvailabilityException exception) {
    final statusColor = exception.available
        ? AppColors.successStrong
        : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceSmall),
      child: Material(
        color: context.tileColor,
        borderRadius: AppRadius.innerCircular,
        child: InkWell(
          borderRadius: AppRadius.innerCircular,
          onTap: () => _editException(exception),
          child: Padding(
            padding: AppPadding.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  AppIcons.calendar,
                  size: AppSizes.iconMedium,
                  color: statusColor,
                ),
                const SizedBox(width: AppSizes.space),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exception.date.asShortDate,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceTiny),
                      Text(
                        exception.available ? 'Çalışabilirim' : 'Çalışamam',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                        ),
                      ),
                      if (exception.note?.isNotEmpty == true) ...[
                        const SizedBox(height: AppSizes.spaceTiny),
                        Text(
                          exception.note!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'İstisnayı sil',
                  onPressed: () => _deleteException(exception),
                  icon: const AppIcon(
                    AppIcons.delete,
                    size: AppSizes.iconSmall,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
