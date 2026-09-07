import 'dart:async';

import 'package:koala/product/constants/app_info.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/employee/features/auth/services/user_service.dart';
import 'package:koala/employee/features/settings/models/chip_read_failure.dart';
import 'package:koala/employee/features/settings/models/identity_chip_result.dart';
import 'package:koala/employee/features/settings/models/mrz_key.dart';
import 'package:koala/employee/features/settings/presentation/widgets/identity_step_row.dart';
import 'package:koala/employee/features/settings/services/chip_reader.dart';
import 'package:koala/employee/features/settings/services/mrz_scanner.dart';
import 'package:koala/employee/features/settings/presentation/widgets/settings_hint.dart';
import 'package:koala/product/constants/app_colors.dart';
import 'package:koala/product/constants/app_icons.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/extensions/date_extensions.dart';
import 'package:koala/product/network/api_exception.dart';
import 'package:koala/product/widgets/app_icon.dart';
import 'package:koala/product/widgets/button_navbar.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';
import 'package:koala/product/widgets/my_textfield.dart';

part 'identity_chip_pagemodel.dart';

/// Kimlik kartının çipini okuyan ekran.
///
/// Sırası kasıtlı: **önce sunucudan tek kullanımlık sayı**, sonra kartın
/// arka yüzündeki MRZ, sonra çip. Sayı en sona bırakılamaz — imzalanacak
/// şey odur.
///
/// Başarılı okumada [IdentityChipResult] ile kapanıyor; kullanıcı vazgeçer
/// ya da NFC hiç yoksa `null` ile kapanıyor ve kimlik ekranı **beyan
/// formuyla eskisi gibi** devam ediyor. Çip bu akışta bir kanıt, bir kapı
/// değil.
///
/// > iOS okuma sırasında kendi sistem NFC sayfasını açıyor ve bu ekran
/// > onun altında kalıyor — bu yüzden ilerleme metni hem burada hem
/// > [ChipReader] üzerinden sistem sayfasında yazılıyor.
class IdentityChipPage extends StatefulWidget {
  const IdentityChipPage({super.key});

  @override
  State<IdentityChipPage> createState() => _IdentityChipPageState();
}

class _IdentityChipPageState extends IdentityChipPagemodel {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MyAppbar(title: 'Kimlik Kartını Okut'),
      bottomNavigationBar: _bottomBar(),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (isPreparing) return const Center(child: CircularProgressIndicator());

    return switch (stage) {
      IdentityChipStage.intro => _intro(),
      IdentityChipStage.manual => _manualForm(),
      IdentityChipStage.reading => _reading(),
      IdentityChipStage.failure => _failure(),
    };
  }

  Widget? _bottomBar() {
    if (isPreparing) return null;

    return switch (stage) {
      IdentityChipStage.intro => ButtonNavbar(
        onPressed: scanAndRead,
        title: 'Kartın Arka Yüzünü Tara',
      ),
      IdentityChipStage.manual => ButtonNavbar(
        onPressed: canReadManually ? readManually : null,
        title: 'Kartı Okut',
      ),
      IdentityChipStage.reading => null,
      IdentityChipStage.failure => null,
    };
  }

  // ------------------------------------------------------------------ Giriş

  Widget _intro() {
    return SingleChildScrollView(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(
            'Kimlik kartının çipini okuyarak doğrulama yapıyoruz. Böylece '
            'bilgileri elle yazman gerekmiyor ve doğrulama çok daha güvenilir '
            'oluyor.',
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          const IdentityStepRow(
            order: 1,
            title: 'Kartın arka yüzünü tara',
            description:
                'Kartı düz bir zemine koy; alt kısmındaki üç satırlık alan '
                'kadraja girsin.',
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          const IdentityStepRow(
            order: 2,
            title: 'Kartı telefonun arkasına yasla',
            description:
                'Çip okunurken kartı ve telefonu hareket ettirme; birkaç '
                'saniye sürüyor.',
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          _manualEntryLink(),
          const SizedBox(height: AppSizes.navBarClearance),
        ],
      ),
    );
  }

  Widget _manualEntryLink() {
    return Center(
      child: TextButton(
        onPressed: openManualEntry,
        child: Text(
          'Kart taranmıyor mu? Bilgileri elle gir',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Elle giriş

  Widget _manualForm() {
    return SingleChildScrollView(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoCard(
            'Bu üç bilgi kartın arka yüzündeki makine okunabilir alanda '
            'yazıyor. Çipi açan anahtar bunlardan üretiliyor, o yüzden '
            'karttakiyle birebir aynı olmalı.',
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          MyTextfield(
            labelText: 'Belge (seri) numarası',
            controller: documentNumber,
            onChanged: (_) => setState(() {}),
          ),
          SettingsHint('Kimlik kartının ön yüzündeki seri numarası.'),
          const SizedBox(height: AppSizes.spaceMedium),
          _dateField(
            label: 'Doğum tarihi',
            value: birthDate,
            onTap: pickBirthDate,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          _dateField(
            label: 'Son geçerlilik tarihi',
            value: expiryDate,
            onTap: pickExpiryDate,
          ),
          SettingsHint(
            'Kartın üzerinde "Son Geçerlilik Tarihi" olarak yazıyor.',
          ),
          const SizedBox(height: AppSizes.navBarClearance),
        ],
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.innerCircular,
      child: Container(
        width: double.infinity,
        padding: AppPadding.primaryAll,
        decoration: BoxDecoration(
          borderRadius: AppRadius.innerCircular,
          border: Border.all(color: context.dividerColor),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value == null ? 'Seç' : value.asShortDate,
              style: context.textTheme.bodyMedium?.copyWith(
                color: value == null ? context.textTertiary : null,
                fontWeight: value == null ? null : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Okuma

  Widget _reading() {
    return Padding(
      padding: AppPadding.primaryAll,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSizes.spaceLarge),
          Text(
            readStep?.label ?? ChipReadStep.waitingForCard.label,
            textAlign: TextAlign.center,
            style: context.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            'Kartı ve telefonu okuma bitene kadar hareket ettirme.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Hata

  Widget _failure() {
    final reason = failure!;

    return SingleChildScrollView(
      padding: AppPadding.primaryAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.spaceLarge),
          AppIcon(
            AppIcons.alert,
            size: AppSizes.iconLarge,
            color: AppColors.warning,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            reason.title,
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSizes.spaceSmall),
          Text(
            reason.message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
              height: _lineHeight,
            ),
          ),
          const SizedBox(height: AppSizes.spaceLarge),
          if (reason.canRetry) ...[
            MyButton(onPressed: retry, title: 'Tekrar Dene'),
            const SizedBox(height: AppSizes.space),
          ],
          // Çip okunamasa da kullanıcı boşlukta kalmıyor: beyan formu
          // eskisi gibi çalışıyor ve doğrulama oradan tamamlanabiliyor.
          MyButton(
            onPressed: abandon,
            title: 'Bilgileri Elle Doğrula',
            isReversed: true,
          ),
          const SizedBox(height: AppSizes.spaceMedium),
          Text(
            'Sorun sürerse ${AppInfo.supportEmail} adresinden bize yazabilirsin.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppSizes.navBarClearance),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Ortak

  /// Bilgilendirme metinlerinin satır aralığı; kimlik ekranındakiyle aynı.
  static const double _lineHeight = 1.4;

  Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: AppPadding.primaryAll,
      decoration: BoxDecoration(
        color: context.tileColor,
        borderRadius: AppRadius.secondaryCircular,
      ),
      child: Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.textSecondary,
          height: _lineHeight,
        ),
      ),
    );
  }
}
