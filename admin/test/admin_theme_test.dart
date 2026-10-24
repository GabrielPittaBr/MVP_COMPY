import 'package:compy_admin/core/theme/admin_colors.dart';
import 'package:compy_admin/core/theme/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Razão de contraste WCAG 2.x entre duas cores.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final scheme = AdminTheme.light.colorScheme;

  test('texto sobre as cores do tema atinge WCAG AA (4,5:1)', () {
    final pairs = <String, (Color, Color)>{
      'onPrimary/primary': (scheme.onPrimary, scheme.primary),
      'onPrimaryContainer/primaryContainer': (
        scheme.onPrimaryContainer,
        scheme.primaryContainer,
      ),
      'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
      'onSecondaryContainer/secondaryContainer': (
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      'onSurface/surface': (scheme.onSurface, scheme.surface),
      'onSurfaceVariant/surface': (scheme.onSurfaceVariant, scheme.surface),
      'onSurfaceVariant/background': (
        scheme.onSurfaceVariant,
        AdminColors.background,
      ),
      'onSurfaceVariant/surfaceContainerHighest': (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      'onErrorContainer/errorContainer': (
        scheme.onErrorContainer,
        scheme.errorContainer,
      ),
      'onWarningContainer/warningContainer': (
        AdminColors.onWarningContainer,
        AdminColors.warningContainer,
      ),
      'secondary/surface': (scheme.secondary, scheme.surface),
      'error/surface': (scheme.error, scheme.surface),
    };
    for (final MapEntry(key: name, value: (foreground, background))
        in pairs.entries) {
      expect(
        _contrast(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    }
  });

  test('borda de componentes atinge 3:1 sobre a superfície', () {
    expect(
      _contrast(scheme.outline, scheme.surface),
      greaterThanOrEqualTo(3),
      reason: 'outline/surface',
    );
  });
}
