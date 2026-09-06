part of 'job_alert_form_page.dart';

abstract class JobAlertFormPageModel extends State<JobAlertFormPage> {
  late final TextEditingController nameController;
  late final TextEditingController salaryController;
  late final ReferenceLocationService locationService;

  JobCategory? selectedCategory;
  ReferenceLocation? selectedCity;
  ReferenceLocation? selectedDistrict;
  JobType? selectedType;
  List<ReferenceLocation> cities = const [];
  List<ReferenceLocation> districts = const [];
  bool isActive = true;
  bool isLoadingLocations = true;
  bool isLoadingDistricts = false;
  bool isSaving = false;
  bool cityWasChanged = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    nameController = TextEditingController(text: alert?.name);
    salaryController = TextEditingController(
      text: alert?.minimumSalary?.toStringAsFixed(0) ?? '',
    );
    selectedCategory = alert?.category;
    selectedType = alert?.type;
    isActive = alert?.isActive ?? true;
    locationService = widget.locationService ?? ReferenceLocationService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<JobCategoryProvider>().load();
      loadLocations();
    });
  }

  Future<void> loadLocations() async {
    setState(() {
      isLoadingLocations = true;
      errorMessage = null;
    });
    try {
      final countries = await locationService.fetchCountries();
      ReferenceLocation? turkey;
      for (final country in countries) {
        if (country.code == 'TR') {
          turkey = country;
          break;
        }
      }
      if (turkey == null) {
        throw StateError('Türkiye referans kaydı bulunamadı.');
      }

      final loadedCities = await locationService.fetchCities(turkey.id);
      final existingCityName = widget.alert?.cityName;
      ReferenceLocation? existingCity;
      for (final city in loadedCities) {
        if (city.name == existingCityName) {
          existingCity = city;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        cities = loadedCities;
        selectedCity = existingCity;
      });
      if (existingCity != null) await loadDistricts(existingCity);
    } catch (_) {
      if (mounted) {
        setState(() {
          errorMessage = 'İl ve ilçe listeleri alınamadı.';
        });
      }
    } finally {
      if (mounted) setState(() => isLoadingLocations = false);
    }
  }

  Future<void> selectCity(ReferenceLocation? city) async {
    setState(() {
      cityWasChanged = true;
      selectedCity = city;
      selectedDistrict = null;
      districts = const [];
    });
    if (city != null) await loadDistricts(city);
  }

  Future<void> loadDistricts(ReferenceLocation city) async {
    setState(() => isLoadingDistricts = true);
    try {
      final loaded = await locationService.fetchDistricts(city.id);
      final existingDistrictName = cityWasChanged
          ? null
          : widget.alert?.districtName;
      ReferenceLocation? existingDistrict;
      for (final district in loaded) {
        if (district.name == existingDistrictName) {
          existingDistrict = district;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        districts = loaded;
        selectedDistrict = existingDistrict;
      });
    } catch (_) {
      if (mounted) {
        setState(() => errorMessage = 'İlçe listesi alınamadı.');
      }
    } finally {
      if (mounted) setState(() => isLoadingDistricts = false);
    }
  }

  Future<void> submit() async {
    final salaryText = salaryController.text.trim().replaceAll(',', '.');
    final parsedSalary = salaryText.isEmpty
        ? null
        : double.tryParse(salaryText);
    if (salaryText.isNotEmpty && parsedSalary == null) {
      setState(() => errorMessage = 'Asgari ücret geçerli bir sayı olmalıdır.');
      return;
    }
    final draft = JobAlertDraft(
      name: nameController.text,
      category: selectedCategory,
      cityName:
          selectedCity?.name ??
          (cityWasChanged ? null : widget.alert?.cityName),
      districtName:
          selectedDistrict?.name ??
          (cityWasChanged ? null : widget.alert?.districtName),
      minimumSalary: parsedSalary,
      type: selectedType,
      isActive: isActive,
    );

    setState(() {
      isSaving = true;
      errorMessage = null;
    });
    final provider = context.read<JobAlertsProvider>();
    final alert = widget.alert;
    final ok = alert == null
        ? await provider.create(draft)
        : await provider.update(alert.id, draft);
    if (!mounted) return;

    setState(() {
      isSaving = false;
      errorMessage = provider.errorMessage;
    });
    if (ok) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    nameController.dispose();
    salaryController.dispose();
    super.dispose();
  }
}
