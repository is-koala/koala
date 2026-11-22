import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';
import 'package:koala/product/widgets/keyboard_done_bar.dart';
import 'package:koala/product/widgets/keyboard_insets.dart';

/// Tek ve çok satırlı metin alanı. iOS'ta geri dönüş tuşsuz sayısal klavyelerde
/// odaklanınca "Bitti" şeridi koyar; şerit kök `Overlay`'e giriyor ki sheet ve
/// diyaloglarda da klavyenin üstünde dursun.
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

  final double height;

  /// Verilen yüksekliği doldur ve metni yukarıdan başlat (uzun metin alanları).
  final bool expands;

  /// Çok satırlı kutularda tam yuvarlak köşe metni sıkıştırır; küçük değer
  /// geçilebilir.
  final BorderRadius borderRadius;

  /// Kapalıyken içerik okunur ama odaklanılamaz.
  final bool enabled;

  final List<TextInputFormatter>? inputFormatters;

  @override
  State<MyTextfield> createState() => _MyTextfieldState();
}

class _MyTextfieldState extends State<MyTextfield> {
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

  /// Platform doğrudan okunuyor: `ThemeData` platformu kurulduğu anda
  /// donduruyor, klavye ise cihaza bağlı.
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
        // Klavye henüz yükselmediyse şerit ekranın dibine yapışmasın.
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
    KeyboardInsets.doneBarVisible.value = true;
  }

  void _removeDoneBar() {
    final entry = _doneBar;
    if (entry == null) return;
    _doneBar = null;
    KeyboardInsets.doneBarVisible.value = false;
    entry.remove();
    entry.dispose();
  }

  /// İmlecin görünür tutulacağı pay. Küçülmeyen ekranda klavye payı, şerit
  /// varsa şerit boyu da ekleniyor ki alan ikisinin üstüne kaydırılsın.
  EdgeInsets _scrollPadding(BuildContext context) {
    const base = EdgeInsets.all(AppSizes.caretScrollPadding);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final doneBar = _needsDoneBar ? AppSizes.keyboardToolbar : 0.0;
    return base.copyWith(bottom: base.bottom + keyboard + doneBar);
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
        scrollPadding: _scrollPadding(context),
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
