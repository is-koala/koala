import 'package:material_ui/material_ui.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/dismiss_keyboard_on_tap.dart';

/// Bottom sheet'lerin ortak kabuğu: zemin, üst köşeler, başlık ve alt güvenli
/// alan.
///
/// İçerik durumluysa `builder` içinde `StatefulBuilder` ile sar. Liste en
/// üstteyken aşağı çekmek sheet'i kapatır ([_PullToDismiss]). Sheet `Scaffold`
/// dışında durduğu için metin alanı taşıyanlar klavye payını kendileri ekler.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  /// Zemin saydam ki köşeler arkadaki beyaz dikdörtgenle kesilmesin.
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

/// Liste en üstteyken aşağı çekilince sheet'i parmakla kaydırır; yeterince
/// çekildiyse kapatır, değilse geri yaylandırır.
///
/// Modal sheet kendi sürüklemesini yalnız kaydırmasız alanda yapıyor, listede
/// hareketi liste yutuyor; burada taşan çekiş (`OverscrollNotification`)
/// sheet'e aktarılıyor. Bu bildirim kenetlenen kaydırmada geldiği için sheet
/// listeleri iOS'ta da [ClampingScrollPhysics] kullanıyor.
class _PullToDismiss extends StatefulWidget {
  const _PullToDismiss({required this.child});

  final Widget child;

  @override
  State<_PullToDismiss> createState() => _PullToDismissState();
}

class _PullToDismissState extends State<_PullToDismiss>
    with SingleTickerProviderStateMixin {
  static const double _dismissFraction = 0.25;

  /// Bu hızdan (px/sn) hızlı fırlatma mesafeye bakmadan kapatır.
  static const double _flingVelocity = 700;

  static const Duration _settle = Duration(milliseconds: 200);

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
        behavior: ScrollConfiguration.of(context)
            .copyWith(physics: const ClampingScrollPhysics()),
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
