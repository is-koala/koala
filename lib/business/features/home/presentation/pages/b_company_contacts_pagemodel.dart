part of 'b_company_contacts_page.dart';

abstract class BCompanyContactsPagemodel extends State<BCompanyContactsPage> {
  static const double _avatarSize = 48;

  CompanyContactService get _service =>
      widget.service ?? CompanyContactService();

  List<CompanyContact> _contacts = const [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _inviteBusy = false;

  CompanyMembership? get _membership =>
      context.read<UserProvider>().user?.primaryCompany;

  bool get canManage => _membership?.isAdmin ?? false;

  String? get _companyId => _membership?.companyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final companyId = _companyId;
    if (companyId == null) {
      setState(() {
        _contacts = const [];
        _errorMessage = 'Kayıtlı firmanız yok';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final contacts = await _service.fetchContacts(companyId);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = CompanyContactService.messageFor(error);
        _isLoading = false;
      });
    }
  }

  Future<void> _invite() async {
    final companyId = _companyId;
    if (companyId == null || _inviteBusy) return;

    final sent = await _InviteContactSheet.show(context);
    if (sent == null || !mounted) return;

    setState(() => _inviteBusy = true);
    try {
      await _service.inviteContact(
        companyId,
        email: sent.email,
        role: sent.role,
      );
      if (!mounted) return;
      AppToast.success(context, 'Davet gönderildi');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, CompanyContactService.messageFor(error));
    } finally {
      if (mounted) setState(() => _inviteBusy = false);
    }
  }

  Future<void> _remove(CompanyContact contact) async {
    final companyId = _companyId;
    if (companyId == null) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Yetkiliyi çıkar',
      message: '${contact.user.fullName} şirket yetkililerinden çıkarılsın mı?',
      actionLabel: 'Çıkar',
    );
    if (confirmed != true || !mounted) return;

    try {
      await _service.removeContact(companyId, contact.user.id);
      if (!mounted) return;
      AppToast.success(context, 'Yetkili çıkarıldı');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      AppToast.error(context, CompanyContactService.messageFor(error));
    }
  }
}

class _InviteDraft {
  const _InviteDraft({required this.email, required this.role});

  final String email;
  final CompanyContactRole role;
}

class _InviteContactSheet extends StatefulWidget {
  const _InviteContactSheet();

  static Future<_InviteDraft?> show(BuildContext context) {
    return AppBottomSheet.show<_InviteDraft>(
      context,
      builder: (_) => const _InviteContactSheet(),
    );
  }

  @override
  State<_InviteContactSheet> createState() => _InviteContactSheetState();
}

class _InviteContactSheetState extends State<_InviteContactSheet> {
  final _emailController = TextEditingController();
  CompanyContactRole _role = CompanyContactRole.staff;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: 'Yetkili Davet Et',
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MyTextfield(
              labelText: 'E-posta',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSizes.spaceMedium),
            _roleField(context),
            const SizedBox(height: AppSizes.spaceLarge),
            MyButton(onPressed: _submit, title: 'Davet Gönder'),
          ],
        ),
      ),
    );
  }

  Widget _roleField(BuildContext context) {
    return Material(
      color: context.tileColor,
      borderRadius: AppRadius.innerCircular,
      child: InkWell(
        borderRadius: AppRadius.innerCircular,
        onTap: () async {
          final selected = await OptionSheet.show<CompanyContactRole>(
            context,
            title: 'Rol',
            options: CompanyContactRole.values,
            labelOf: (role) => role.displayName,
            selected: _role,
          );
          if (selected == null || !mounted) return;
          setState(() => _role = selected);
        },
        child: Padding(
          padding: AppPadding.tileTall,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Rol · ${_role.displayName}',
                  style: context.textTheme.bodyMedium,
                ),
              ),
              AppIcon(
                AppIcons.arrowRight,
                size: AppSizes.iconMedium,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppToast.error(context, 'E-posta adresi boş bırakılamaz');
      return;
    }
    Navigator.pop(context, _InviteDraft(email: email, role: _role));
  }
}
