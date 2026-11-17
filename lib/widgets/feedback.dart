import 'package:flutter/material.dart';

import '../core/theme.dart';

// ===== Feedback =====

void toast(BuildContext context, String msg, {bool erro = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              erro ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: erro ? AppColors.danger : AppColors.success,
      ),
    );
}
