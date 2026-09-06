import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/employee/features/home/presentation/providers/job_category_provider.dart';
import 'package:koala/employee/features/jobs/models/job_alert.dart';
import 'package:koala/employee/features/jobs/presentation/providers/job_alerts_provider.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/reference_location.dart';
import 'package:koala/product/services/reference_location_service.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

part 'job_alert_form_pagemodel.dart';

class JobAlertFormPage extends StatefulWidget {
  const JobAlertFormPage({super.key, this.alert, this.locationService});

  final JobAlert? alert;
  final ReferenceLocationService? locationService;

  @override
  State<JobAlertFormPage> createState() => _JobAlertFormPageState();
}

class _JobAlertFormPageState extends JobAlertFormPagemodel {
  @override
  Widget build(BuildContext context) {
    final categories = context.watch<JobCategoryProvider>().categories;

    return Scaffold(
      appBar: MyAppbar(
        title: widget.alert == null ? 'Yeni İş Alarmı' : 'Alarmı Düzenle',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MyTextfield(
                labelText: 'Alarm adı',
                controller: nameController,
                inputFormatters: [LengthLimitingTextInputFormatter(255)],
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              _dropdown<JobCategory>(
                label: 'Kategori',
                value: categories.contains(selectedCategory)
                    ? selectedCategory
                    : null,
                items: categories,
                labelOf: (category) => category.name,
                onChanged: (value) => setState(() => selectedCategory = value),
                onClear: () => setState(() => selectedCategory = null),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              _dropdown<ReferenceLocation>(
                label: 'İl',
                value: selectedCity,
                items: cities,
                labelOf: (city) => city.name,
                onChanged: isLoadingLocations ? null : selectCity,
                onClear: () => selectCity(null),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              _dropdown<ReferenceLocation>(
                label: 'İlçe',
                value: selectedDistrict,
                items: districts,
                labelOf: (district) => district.name,
                onChanged: selectedCity == null || isLoadingDistricts
                    ? null
                    : (value) => setState(() => selectedDistrict = value),
                onClear: () => setState(() => selectedDistrict = null),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: 'Asgari ücret',
                controller: salaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              _dropdown<JobType>(
                label: 'İlan türü',
                value: selectedType,
                items: JobType.values,
                labelOf: (type) => type.displayName,
                onChanged: (value) => setState(() => selectedType = value),
                onClear: () => setState(() => selectedType = null),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alarm etkin',
                          style: context.textTheme.titleSmall,
                        ),
                        Text(
                          'Pasif alarm listede kalır ancak yeni ilanları '
                          'izlemez.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isActive,
                    onChanged: (value) => setState(() => isActive = value),
                  ),
                ],
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSizes.spaceMedium),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.spaceLarge),
              MyButton(
                onPressed: submit,
                title: widget.alert == null ? 'Alarmı Oluştur' : 'Kaydet',
                isLoading: isSaving,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?>? onChanged,
    required VoidCallback onClear,
  }) {
    return DropdownButtonFormField<T>(
      key: ValueKey('$label-${value?.hashCode ?? 'empty'}'),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value == null || onChanged == null
            ? null
            : IconButton(
                tooltip: '$label seçimini temizle',
                onPressed: onClear,
                icon: const AppIcon(AppIcons.cancelCircle),
              ),
      ),
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
