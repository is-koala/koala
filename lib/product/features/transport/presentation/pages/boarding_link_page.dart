import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/features/transport/models/boarding.dart';
import 'package:koala/product/features/transport/presentation/widgets/boarding_result_panel.dart';
import 'package:koala/product/widgets/my_appbar.dart';
import 'package:koala/product/widgets/my_button.dart';

/// Bağlantıdaki token'ı gönderen fonksiyon; oturumun tarafına göre
/// rotada seçiliyor (işçi kuyruğu ya da işverenin koltuk işareti).
typedef BoardingLinkSubmit =
    Future<BoardingResultPanel> Function(
      BuildContext context,
      BoardingToken token,
      DateTime capturedAt,
    );

/// Telefonun kendi kamerasıyla okutulan `{şema}://board?t=<token>`
/// bağlantısı (is-koala/koala#217). `AppLinkDestination` bunu
/// `/boarding-link?t=…`'ye çeviriyor; rota iki tarafa da açık.
///
/// Servis QR'ı (`s1.`) işçinin, çalışan QR'ı (`w1.`) işverenin işi: yanlış
/// tarafın açtığı bağlantı gönderilmez, ne yapılacağı söylenir. Sayfa
/// açılır açılmaz bir kez gönderir; "Tamam" kendi ana sayfasına götürür.
class BoardingLinkPage extends StatefulWidget {
  const BoardingLinkPage({
    super.key,
    required this.token,
    required this.acceptedKind,
    required this.homeRoute,
    required this.submit,
    this.now,
  });

  /// Bağlantının `t` parametresi.
  final String token;
  final BoardingTokenKind acceptedKind;
  final String homeRoute;
  final BoardingLinkSubmit submit;
  final DateTime Function()? now;

  static const String invalidMessage =
      'Bu biniş bağlantısı geçersiz. QR\'ı Koala uygulamasının içinden '
      'okutmayı deneyin.';

  static String wrongSideMessage(BoardingTokenKind accepted) =>
      accepted == BoardingTokenKind.shuttle
      ? 'Bu bir çalışan QR\'ı; işverenin okutması gerekiyor. Siz servisteki '
            'QR\'ı okutun.'
      : 'Bu bir servis QR\'ı; çalışanların okutması içindir. Çalışanın '
            'kişisel QR\'ını okutun.';

  @override
  State<BoardingLinkPage> createState() => _BoardingLinkPageState();
}

class _BoardingLinkPageState extends State<BoardingLinkPage> {
  BoardingResultPanel? _result;

  @override
  void initState() {
    super.initState();
    final capturedAt = (widget.now ?? DateTime.now)().toUtc();
    final token = BoardingToken.fromValue(widget.token);
    if (token == null) {
      _result = const BoardingResultPanel(
        tone: BoardingResultTone.failure,
        message: BoardingLinkPage.invalidMessage,
      );
    } else if (token.kind != widget.acceptedKind) {
      _result = BoardingResultPanel(
        tone: BoardingResultTone.failure,
        message: BoardingLinkPage.wrongSideMessage(widget.acceptedKind),
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_send(token, capturedAt));
      });
    }
  }

  Future<void> _send(BoardingToken token, DateTime capturedAt) async {
    final result = await widget.submit(context, token, capturedAt);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: const MyAppbar(title: 'Servis binişi', showBackButton: false),
      body: SafeArea(
        child: Padding(
          padding: AppPadding.primaryAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result == null)
                Column(
                  key: const ValueKey('boarding-link-sending'),
                  children: [
                    const SizedBox(height: AppSizes.spaceLarge),
                    CircularProgressIndicator(color: context.accentColor),
                    const SizedBox(height: AppSizes.space),
                    Text(
                      'Biniş gönderiliyor…',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                )
              else
                result,
              const Spacer(),
              MyButton(
                key: const ValueKey('boarding-link-done'),
                title: 'Tamam',
                onPressed: result == null
                    ? null
                    : () => context.go(widget.homeRoute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
