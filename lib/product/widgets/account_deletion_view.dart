import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/models/account_deletion.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/confirm_dialog.dart';
import 'package:koala/product/widgets/form_page_body.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

typedef AccountDeletionRequest =
    Future<AccountDeletion> Function({String? reason});

/// Hesap silme talebini iki uygulama için aynı davranışla başlatır.
///
/// Silme anlık olmadığı için bu görünüm oturumu kapatmaz. Backend talebi
/// bekleme süresi ve açık yükümlülük kontrollerinden sonra anonimleştirir;
/// kullanıcı bu sırada hesabındaki son durumu görmeye devam edebilir.
class AccountDeletionView extends StatefulWidget {
  const AccountDeletionView({super.key, required this.requestDeletion});

  /// Widget testinin davranışı gerçek HTTP olmadan gözleyebilmesi için seam.
  /// Çalışma zamanında iki sayfa da aynı `LegalService` metodunu verir.
  final AccountDeletionRequest requestDeletion;

  @override
  State<AccountDeletionView> createState() => _AccountDeletionViewState();
}

class _AccountDeletionViewState extends State<AccountDeletionView> {
  /// Gerekçe zorunlu değil; alan bir açıklama cümlesi taşıyabilecek kadar uzun.
  static const double _reasonFieldHeight = 132;

  final TextEditingController _reasonController = TextEditingController();
  bool _isLoading = false;
  AccountDeletion? _deletion;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Hesabını sil',
      message:
          'Bu talep işlendiğinde hesabın ve yasal olarak saklanması '
          'gerekmeyen kişisel verilerin geri alınamayacak şekilde silinir '
          'veya anonimleştirilir.',
      actionLabel: 'Hesabımı Sil',
    );
    if (confirmed != true || _isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final trimmedReason = _reasonController.text.trim();

    try {
      final deletion = await widget.requestDeletion(
        reason: trimmedReason.isEmpty ? null : trimmedReason,
      );
      if (!mounted) return;
      setState(() => _deletion = deletion);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deletion = _deletion;
    if (deletion != null) return _success(deletion);

    return FormPageBody(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Hesap silme talebi', style: context.textTheme.titleLarge),
          const SizedBox(height: AppSizes.space),
          Text(
            'Bu işlem geri alınamaz. Talep, bekleme süresi ile devam eden iş, '
            'uyuşmazlık ve ödeme kontrolleri tamamlandıktan sonra işlenir.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _retentionNotice(),
          const SizedBox(height: AppSizes.spaceLarge),
          MyTextfield(
            labelText: 'Silme nedeni (isteğe bağlı)',
            controller: _reasonController,
            height: _reasonFieldHeight,
            expands: true,
            borderRadius: AppRadius.secondaryCircular,
            inputFormatters: [LengthLimitingTextInputFormatter(512)],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSizes.space),
            Text(
              _errorMessage!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spaceLarge),
          MyButton(
            onPressed: _request,
            title: 'Silme Talebi Oluştur',
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _retentionNotice() {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: AppRadius.secondaryCircular,
        border: Border.all(color: context.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.info,
            size: AppSizes.iconMedium,
            color: context.textSecondary,
          ),
          const SizedBox(width: AppSizes.spaceSmall),
          Expanded(
            child: Text(
              'Ödeme, fatura ve sözleşme kayıtları yasal saklama '
              'yükümlülükleri nedeniyle kimliğinden ayrıştırılmış biçimde '
              'tutulabilir.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success(AccountDeletion deletion) {
    return Center(
      child: SingleChildScrollView(
        padding: AppPadding.primaryAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppIcon(
              AppIcons.checkCircle,
              size: AppSizes.iconHuge,
              color: AppColors.success,
              filled: true,
            ),
            const SizedBox(height: AppSizes.spaceLarge),
            Text('Talebin alındı', style: context.textTheme.titleLarge),
            const SizedBox(height: AppSizes.spaceSmall),
            Text(
              deletion.isBlocked
                  ? 'Aşağıdaki engel kalktığında bekleme süresi ve uygunluk '
                        'kontrolleri tamamlanarak hesabın anonimleştirilecek.'
                  : 'Hesabın bekleme süresi ve uygunluk kontrollerinden sonra '
                        'anonimleştirilecek.',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            if (deletion.isBlocked) ...[
              const SizedBox(height: AppSizes.spaceMedium),
              Container(
                padding: AppPadding.card,
                decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: AppRadius.secondaryCircular,
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppIcon(
                      AppIcons.info,
                      size: AppSizes.iconMedium,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSizes.spaceSmall),
                    Expanded(
                      child: Text(
                        deletion.blockedReason!,
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
