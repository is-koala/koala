part of 'company_invitation_page.dart';

abstract class CompanyInvitationPagemodel extends State<CompanyInvitationPage> {
  final CompanyContactService _service = CompanyContactService();

  CompanyContactInvitation? _invitation;
  bool _isLoading = false;
  bool _isBusy = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (widget.invitationId.isEmpty) {
      setState(() {
        _errorMessage = 'Davet bulunamadı ya da size ait değil.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invitation = await _service.fetchInvitation(widget.invitationId);
      if (!mounted) return;
      setState(() {
        _invitation = invitation;
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

  Future<void> _answer({required bool accepted}) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);
    try {
      final invitation = await _service.answerInvitation(
        widget.invitationId,
        accepted: accepted,
      );
      if (!mounted) return;
      setState(() {
        _invitation = invitation;
        _isBusy = false;
      });
      if (accepted) {
        await context.read<UserProvider>().load(silent: true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      AppToast.error(context, CompanyContactService.messageFor(error));
      if (error.errorCode == 'INVITATION_ALREADY_ANSWERED') {
        await _load();
      }
    }
  }
}
