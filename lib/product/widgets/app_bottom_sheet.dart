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

/// İçerideki dikey liste en üstteyken aşağı çekilince sheet'i parmakla
/// birlikte aşağı kaydırır; bırakınca yeterince çekildiyse kapatır, değilse
/// yerine yaylandırır.
///
/// Flutter'ın modal sheet'i kendi sürüklemesini yalnız kaydırma içermeyen
/// alanda yapıyor; içerik bir listeyse hareketi liste yutuyor. Burada listenin
/// üst kenardan taşan çekişi (`OverscrollNotification`) sheet'in kaymasına
/// çevriliyor. Taşma bildirimi kenetlenen kaydırmada geldiği için sheet
/// içindeki listeler iOS'ta da [ClampingScrollPhysics] kullanıyor; esneyen
/// liste sheet'le birlikte çifte hareket ederdi. Yatay şeritler ve
/// programatik kaydırma sayılmıyor; yalnız bir bottom sheet rotasında çalışır.
class _PullToDismiss extends StatefulWidget {
  const _PullToDismiss({required this.child});

  final Widget child;

  @override
  State<_PullToDismiss> createState() => _PullToDismissState();
}

class _PullToDismissState extends State<_PullToDismiss>
    with SingleTickerProviderStateMixin {
  /// Sheet boyunun bu oranından fazla çekilirse bırakınca kapanır.
  static const double _dismissFraction = 0.25;

  /// Bu hızdan (piksel/sn) hızlı aşağı fırlatma, mesafeye bakmadan kapatır.
  static const double _flingVelocity = 700;

  static const Duration _settle = Duration(milliseconds: 200);

  /// Sheet'in şu anki aşağı kayması (piksel).
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  bool _dragging = false;
  bool _dismissed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool get _inSheet => ModalRoute.of(context) is ModalBottomSheetRoute;

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || !_inSheet) return false;

    if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0) {
      _dragging = true;
      _offset.value -= notification.overscroll;
    } else if (notification is ScrollUpdateNotification &&
        _dragging &&
        (notification.scrollDelta ?? 0) > 0 &&
        _offset.value > 0) {
      // Sheet aşağıdayken parmak geri yukarı: önce sheet yukarı gelsin.
      _offset.value = (_offset.value - notification.scrollDelta!).clamp(
        0,
        double.infinity,
      );
    } else if (notification is ScrollEndNotification && _dragging) {
      _dragging = false;
      _release(notification.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  void _release(double velocity) {
    final height = context.size?.height ?? 0;
    final pulledFar = height > 0 && _offset.value > height * _dismissFraction;
    if (!_dismissed && (pulledFar || velocity > _flingVelocity)) {
      _dismissed = true;
      Navigator.of(context).maybePop();
      return;
    }
    _offset.animateTo(0, duration: _settle, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(physics: const ClampingScrollPhysics()),
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _offset.value.clamp(0, double.infinity)),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
