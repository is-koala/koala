import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/constants/app_radius.dart';
import 'package:koala/product/constants/app_sizes.dart';
import 'package:koala/product/extensions/context_extensions.dart';

class MyTextfield extends StatelessWidget {
  const MyTextfield({
    super.key,
    required this.labelText,
    this.isObscureText = false,
    this.suffixIcon,
    this.showSuffixIcon,
    this.controller,
    this.onChanged,
    this.keyboardType = TextInputType.text,
    this.height = AppSizes.fieldHeight,
    this.expands = false,
    this.borderRadius = AppRadius.primaryCircular,
    this.enabled = true,
  });

  final String labelText;
  final bool isObscureText;
  final Widget? suffixIcon;
  final bool? showSuffixIcon;
  final TextEditingController? controller;
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

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        obscureText: isObscureText,
        maxLines: expands ? null : 1,
        expands: expands,
        textAlignVertical: expands ? TextAlignVertical.top : null,
        decoration: InputDecoration(
          labelText: labelText,
          alignLabelWithHint: expands,
          labelStyle: context.textTheme.bodyLarge?.copyWith(
            color: context.textSecondary,
          ),
          border: OutlineInputBorder(borderRadius: borderRadius),
          focusedBorder: OutlineInputBorder(
            borderRadius: borderRadius,
            borderSide: BorderSide(color: context.accentColor, width: 2.0),
          ),
          contentPadding: AppPadding.field,
          isDense: true,
          suffixIcon: showSuffixIcon == true ? suffixIcon : null,
        ),
        style: context.textTheme.bodyLarge,
        keyboardType: keyboardType,
      ),
    );
  }
}
