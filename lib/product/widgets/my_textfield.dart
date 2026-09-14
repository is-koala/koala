import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/keyboard_done_bar.dart';

/// Uygulamanın tek satırlık ve çok satırlık metin alanı.
///
/// iOS'ta geri dönüş tuşu olmayan sayısal klavyelerde ([KeyboardDoneBar.needsFor])
/// alan odaklanınca klavyenin üstüne bir "Bitti" şeridi yerleştiriyor; odak
/// düşünce şerit kalkıyor. Şerit kök `Overlay`'e giriyor ki sheet ve
/// diyaloglardaki alanlarda da klavyenin üstünde dursun.
class MyTextfield extends StatefulWidget {
  const MyTextfield({
    super.key,
    required this.labelText,
    this.isObscureText = false,
    this.suffixIcon,
    this.showSuffixIcon,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.height = AppSizes.fieldHeight,
    this.expands = false,
    this.borderRadius = AppRadius.primaryCircular,
    this.enabled = true,
    this.inputFormatters,
  });

  final String labelText;
  final bool isObscureText;
  final Widget? suffixIcon;
  final bool? showSuffixIcon;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Function(String)? onChanged;
  final TextInputType keyboardType;

  /// Alanın yüksekliği. Çok satırlı kullanımda ([expands] true iken)
  /// büyütülür; tek satırlıkta varsayılan bırakılır.
  final double height;

  /// Alan verilen yüksekliği doldursun ve metin yukarıdan başlasın mı.
  /// Açıklama gibi uzun metin alanları için.
  final bool expands;

  /// Çerçevenin köşe yuvarlaklığı. Tek satırlık alanlar tam yuvarlak durur;
  /// çok satırlı kutularda o kadar yuvarlak köşe metni sıkıştırdığı için
  /// daha küçük bir değer geçilebilir.
  final BorderRadius borderRadius;

  /// Alan düzenlenebilir mi. Kapalıyken içerik okunabilir kalıyor ama
  /// odaklanılamıyor: karşılığı henüz olmayan ya da başka bir ekrandan
  /// değiştirilen alanlar için.
  final bool enabled;

  /// Girişi kısıtlayan biçimlendiriciler: yalnızca rakam, uzunluk sınırı vb.
  /// Sunucunun deseni ayrıca doğruluyor; bu, kullanıcıya yanlış yazdırmamak
  /// için.
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<MyTextfield> createState() => _MyTextfieldState();
}

class _MyTextfieldState extends State<MyTextfield> {
  /// Dışarıdan düğüm verilmediğinde odağı izlemek için kurulan düğüm.
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  OverlayEntry? _doneBar;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(MyTextfield oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocusNode)?.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _removeDoneBar();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  /// Platform temadan değil doğrudan okunuyor: `ThemeData` platformu
  /// kurulduğu anda donduruyor, klavye davranışı ise çalışılan cihaza bağlı.
  bool get _needsDoneBar =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      KeyboardDoneBar.needsFor(widget.keyboardType);

  void _onFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus && _needsDoneBar) {
      _showDoneBar();
    } else {
      _removeDoneBar();
    }
  }

  void _showDoneBar() {
    if (_doneBar != null) return;
    final entry = OverlayEntry(
      builder: (overlayContext) {
        // Klavye henüz yükselmediyse (ya da donanım klavyesi varsa) şerit
        // ekranın dibine yapışmasın; klavye görününce yerini alıyor.
        final keyboard = MediaQuery.viewInsetsOf(overlayContext).bottom;
        if (keyboard <= 0) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: keyboard,
          child: KeyboardDoneBar(onDone: _focusNode.unfocus),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    _doneBar = entry;
  }

  void _removeDoneBar() {
    final entry = _doneBar;
    if (entry == null) return;
    _doneBar = null;
    entry.remove();
    entry.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: widget.onChanged,
        obscureText: widget.isObscureText,
        maxLines: widget.expands ? null : 1,
        expands: widget.expands,
        textAlignVertical: widget.expands ? TextAlignVertical.top : null,
        decoration: InputDecoration(
          labelText: widget.labelText,
          alignLabelWithHint: widget.expands,
          labelStyle: context.textTheme.bodyLarge?.copyWith(
            color: context.textSecondary,
          ),
          border: OutlineInputBorder(borderRadius: widget.borderRadius),
          focusedBorder: OutlineInputBorder(
            borderRadius: widget.borderRadius,
            borderSide: BorderSide(color: context.accentColor, width: 2.0),
          ),
          contentPadding: AppPadding.field,
          isDense: true,
          suffixIcon: widget.showSuffixIcon == true ? widget.suffixIcon : null,
        ),
        style: context.textTheme.bodyLarge,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
      ),
    );
  }
}
