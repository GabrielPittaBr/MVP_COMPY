import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

enum AdminStatusTone { positive, info, neutral, negative }

/// Estado em cor e em palavra; a cor nunca aparece sozinha.
class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({required this.label, required this.tone, super.key});

  final String label;
  final AdminStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, dot) = switch (tone) {
      AdminStatusTone.positive => (
        AdminColors.secondaryContainer,
        AdminColors.onSecondaryContainer,
        AdminColors.secondary,
      ),
      AdminStatusTone.info => (
        AdminColors.primaryContainer,
        AdminColors.primary,
        AdminColors.primary,
      ),
      AdminStatusTone.neutral => (
        AdminColors.surfaceContainer,
        AdminColors.onSurfaceVariant,
        AdminColors.outline,
      ),
      AdminStatusTone.negative => (
        AdminColors.errorContainer,
        AdminColors.onErrorContainer,
        AdminColors.error,
      ),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
