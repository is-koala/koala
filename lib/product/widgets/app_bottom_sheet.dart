import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/dismiss_keyboard_on_tap.dart';

/// Uygulamadaki bottom sheet'lerin ortak kabuğu: zemin, üst köşeler, başlık
/// satırı ve alt güvenli alan payı.
///
/// İçeriğin kendi durumu varsa `builder` içinde bir `StatefulBuilder` ile
/// sarmalayıp bu widget'ı onun altında kur; kabuk durumla ilgilenmiyor.
///
/// İçindeki dikey liste en üstteyken aşağı çekilmeye devam edilirse sheet
/// kapanıyor ([_PullToDismiss]); ilan detayı sheet'i `DraggableScrollableSheet`
/// ile bunu zaten yapıyordu, kaydırma içeren diğer sheet'lerde hareketi liste
/// yutuyordu.
///
/// Kabuğun boş alanına dokunmak klavyeyi kapatıyor; metin alanı taşıyan
/// sheet'ler klavye payını (`viewInsets`) kendileri ekliyor, çünkü sheet
/// `Scaffold`'un dışında, Navigator katmanında duruyor.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  /// Sheet'i açar. Zemin saydam veriliyor ki köşe yuvarlaklığı arkasındaki
  /// varsayılan beyaz dikdörtgenle kesilmesin.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PullToDismiss(
      child: DismissKeyboardOnTap(
        child: Container(
          decoration: BoxDecoration(
            color: context.backgroundColor,
            borderRadius: AppRadius.sheetTop,
          ),
          padding: AppPadding.sheet.copyWith(
            bottom: context.padding.bottom + AppPadding.sheet.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: context.textTheme.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceMedium),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// İçerideki dikey listenin üst kenarından taşan aşağı çekişi toplar;
/// [AppSizes.sheetPullToDismiss]'i geçince sheet'i kapatır.
///
/// Android'in kenetlenen kaydırması taşmayı `OverscrollNotification` ile,
/// iOS'un esneyen kaydırması da konumun sıfırın altına inmesiyle bildiriyor;
/// ikisi de sayılıyor. Yalnız dikey eksen ve yalnız kullanıcının parmağıyla
/// gelen hareket (`dragDetails`) sayılıyor: yatay çip şeritleri ya da
/// programatik kaydırma sheet'i kapatmaz. Yalnız bir bottom sheet rotası
/// içindeyken çalışır.
class _PullToDismiss extends StatefulWidget {
  const _PullToDismiss({required this.child});

  final Widget child;

  @override
  State<_PullToDismiss> createState() => _PullToDismissState();
}

class _PullToDismissState extends State<_PullToDismiss> {
  double _pulled = 0;
  bool _dismissed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _pulled = 0;
      return false;
    }

    double pull = 0;
    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      pull = -notification.overscroll;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels < notification.metrics.minScrollExtent &&
        (notification.scrollDelta ?? 0) < 0) {
      pull = -notification.scrollDelta!;
    }
    if (pull == 0) return false;

    _pulled += pull;
    if (_pulled >= AppSizes.sheetPullToDismiss && !_dismissed) {
      final route = ModalRoute.of(context);
      if (route is ModalBottomSheetRoute) {
        _dismissed = true;
        Navigator.of(context).maybePop();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: widget.child,
    );
  }
}
