import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/business/features/home/presentation/providers/b_jobs_provider.dart';
import 'package:koala/business/features/home/services/fake_business_company.dart';
import 'package:koala/employee/features/home/models/job.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_textfield.dart';
import 'package:provider/provider.dart';

class BCreatePage extends StatefulWidget {
  const BCreatePage({super.key});

  @override
  State<BCreatePage> createState() => _BCreatePageState();
}

class _BCreatePageState extends State<BCreatePage> {
  /// Açıklama alanının yüksekliği: yaklaşık dört satır.
  static const double _descriptionHeight = 120;

  /// Başarı diyaloğundaki tik dairesi.
  static const double _successCircleSize = 72;
  static const double _successIconSize = 48;

  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  final _sectorController = TextEditingController();
  final _positionController = TextEditingController();
  final _dutiesController = TextEditingController();
  final _dressCodeController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();

  JobCategory _selectedCategory = JobCategory.waiter;
  JobType _selectedType = JobType.oneTime;
  bool _experienceRequired = false;
  bool _insuranceRequired = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _addressController.dispose();
    _sectorController.dispose();
    _positionController.dispose();
    _dutiesController.dispose();
    _dressCodeController.dispose();
    _minAgeController.dispose();
    _maxAgeController.dispose();
    super.dispose();
  }

  void _createJob() {
    if (_titleController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen başlık ve ücret alanlarını doldurun'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final companyName = FakeBusinessCompany.instance.name;
    final now = DateTime.now();
    final jobId = 'b_${now.millisecondsSinceEpoch}';

    final job = Job(
      id: jobId,
      latitude: 39.9208,
      longitude: 32.8541,
      type: _selectedType,
      category: _selectedCategory,
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim().isEmpty
          ? _titleController.text.trim()
          : _subtitleController.text.trim(),
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      company: companyName,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      sector: _sectorController.text.trim().isEmpty
          ? null
          : _sectorController.text.trim(),
      position: _positionController.text.trim().isEmpty
          ? null
          : _positionController.text.trim(),
      duties: _dutiesController.text.trim().isEmpty
          ? null
          : _dutiesController.text.trim(),
      insuranceRequired: _insuranceRequired,
      startDateTime: now,
      salaryType: 'FIXED',
      minAge: int.tryParse(_minAgeController.text.trim()),
      maxAge: int.tryParse(_maxAgeController.text.trim()),
      experienceRequired: _experienceRequired,
      dressCode: _dressCodeController.text.trim().isEmpty
          ? null
          : _dressCodeController.text.trim(),
      employerType: 'COMPANY',
      address: _addressController.text.trim().isEmpty
          ? 'Ankara'
          : _addressController.text.trim(),
    );

    context.read<BJobsProvider>().createJobPost(job);
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.secondaryCircular,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spaceLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _successCircleSize,
                height: _successCircleSize,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: _successIconSize,
                ),
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              Text(
                'İlan Oluşturuldu!',
                style: context.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.spaceSmall),
              Text(
                'İlanınız başarıyla oluşturuldu ve aktif ilanlarınızda görüntülenecek.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSizes.spaceLarge),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.go('/business/posts');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: context.onAccentColor,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.innerCircular,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.spaceMedium,
                    ),
                    textStyle: context.textTheme.labelLarge,
                  ),
                  child: const Text('İlanlarıma Git'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: MyAppbar(title: "Yeni İlan Oluştur"),
      bottomNavigationBar: ButtonNavbar(
        onPressed: _createJob,
        title: "İlanı Yayınla",
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temel Bilgiler
              _sectionLabel("Temel Bilgiler"),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "İlan Başlığı *",
                controller: _titleController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Kısa Açıklama",
                controller: _subtitleController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Ücret (₺) *",
                controller: _priceController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Adres", controller: _addressController),

              const SizedBox(height: AppSizes.spaceLarge),

              // Kategori & Tip
              _sectionLabel("Kategori ve Tip"),
              const SizedBox(height: AppSizes.space),
              _categorySelector(),
              const SizedBox(height: AppSizes.spaceMedium),
              _typeSelector(),

              const SizedBox(height: AppSizes.spaceLarge),

              // Detaylı Bilgiler
              _sectionLabel("Detaylı Bilgiler"),
              const SizedBox(height: AppSizes.space),
              _descriptionTextField(),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Sektör", controller: _sectorController),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Pozisyon",
                controller: _positionController,
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(labelText: "Görevler", controller: _dutiesController),

              const SizedBox(height: AppSizes.spaceLarge),

              // Gereksinimler
              _sectionLabel("Gereksinimler"),
              const SizedBox(height: AppSizes.space),
              Row(
                children: [
                  Expanded(
                    child: MyTextfield(
                      labelText: "Min Yaş",
                      controller: _minAgeController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceMedium),
                  Expanded(
                    child: MyTextfield(
                      labelText: "Max Yaş",
                      controller: _maxAgeController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              MyTextfield(
                labelText: "Kıyafet Kuralı",
                controller: _dressCodeController,
              ),
              const SizedBox(height: AppSizes.space),
              _switchTile(
                title: "Deneyim Gerekli",
                value: _experienceRequired,
                onChanged: (v) => setState(() => _experienceRequired = v),
              ),
              _switchTile(
                title: "Sigorta Gerekli",
                value: _insuranceRequired,
                onChanged: (v) => setState(() => _insuranceRequired = v),
              ),

              const SizedBox(height: AppSizes.navBarClearance),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) =>
      Text(title, style: context.textTheme.titleMedium);

  Widget _categorySelector() {
    return Wrap(
      spacing: AppSizes.spaceSmall,
      runSpacing: AppSizes.spaceSmall,
      children: JobCategory.values.map((category) {
        final isSelected = _selectedCategory == category;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = category),
          child: Container(
            padding: AppPadding.chip,
            decoration: BoxDecoration(
              color: isSelected
                  ? category.color.withValues(alpha: 0.15)
                  : context.tileColor,
              borderRadius: AppRadius.innerCircular,
              border: Border.all(
                color: isSelected ? category.color : context.dividerColor,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  category.icon,
                  size: AppSizes.iconSmall,
                  color: isSelected ? category.color : context.textSecondary,
                ),
                const SizedBox(width: AppSizes.spaceTiny),
                Text(
                  category.displayName,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? category.color : context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _typeSelector() {
    return Row(
      children: JobType.values.map((type) {
        final isSelected = _selectedType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedType = type),
            child: Container(
              margin: EdgeInsets.only(
                right: type == JobType.oneTime ? AppSizes.spaceSmall : 0,
                left: type == JobType.recurring ? AppSizes.spaceSmall : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.space),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.accentColor.withValues(alpha: 0.1)
                    : context.tileColor,
                borderRadius: AppRadius.innerCircular,
                border: Border.all(
                  color: isSelected
                      ? context.accentColor
                      : context.dividerColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  type.displayName,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? context.accentColor
                        : context.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _descriptionTextField() {
    return MyTextfield(
      labelText: "Açıklama",
      controller: _descriptionController,
      height: _descriptionHeight,
      expands: true,
      // Tek satırlık alanların tam yuvarlak köşesi bu yükseklikte metni
      // sıkıştırıyor.
      borderRadius: AppRadius.innerCircular,
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceTiny),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: context.accentColor,
          ),
        ],
      ),
    );
  }
}
