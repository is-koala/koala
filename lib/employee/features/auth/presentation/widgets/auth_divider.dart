import 'package:flutter/material.dart';
import 'package:koala/product/constants/app_padding.dart';
import 'package:koala/product/extensions/context_extensions.dart';

/// Ana eylem butonu ile Google butonu arasındaki "YA DA" ayracı.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppPadding.horizontalSmall,
      child: Row(
        children: [
          Expanded(child: Divider(color: context.dividerColor, thickness: 1)),
          Padding(
            padding: AppPadding.primaryHorizontal,
            child: Text(
              'YA DA',
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.dividerColor, thickness: 1)),
        ],
      ),
    );
  }
}
