// test/theme_test.dart
// Verifies the light + dark theme tokens are well-formed and contrasting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  group('AppTheme.light()', () {
    final theme = AppTheme.light();

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('brightness is light', () {
      expect(theme.brightness, Brightness.light);
    });

    test('scaffold background is light', () {
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
    });

    test('primary color is Emerald Green 800', () {
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.primary, const Color(0xFF2E7D32));
    });

    test('secondary color is Teal 400', () {
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.secondary, const Color(0xFF26A69A));
    });

    test('card theme has 16dp radius (canonical)', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      final radius = shape.borderRadius as BorderRadius;
      expect(radius.topLeft.x, AppRadius.l);
    });
  });

  group('AppTheme.dark()', () {
    final theme = AppTheme.dark();

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('brightness is dark', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffold background is the dark surface', () {
      expect(theme.scaffoldBackgroundColor, AppColors.backgroundDark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0F1419));
    });

    test('primary uses brighter Green 500 for dark-bg contrast', () {
      expect(theme.colorScheme.primary, AppColors.primaryLight);
      expect(theme.colorScheme.primary, const Color(0xFF4CAF50));
    });

    test('card theme has 16dp radius (canonical)', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      final radius = shape.borderRadius as BorderRadius;
      expect(radius.topLeft.x, AppRadius.l);
    });
  });

  group('SemanticColors', () {
    test('light mode tokens', () {
      const s = SemanticColors.lightTokens;
      expect(s.background, AppColors.backgroundLight);
      expect(s.surface, AppColors.surfaceLight);
      expect(s.textPrimary, AppColors.textPrimaryLight);
    });

    test('dark mode tokens', () {
      const s = SemanticColors.darkTokens;
      expect(s.background, AppColors.backgroundDark);
      expect(s.surface, AppColors.surfaceDark);
      expect(s.textPrimary, AppColors.textPrimaryDark);
    });

    test('text color differs between modes (light is dark, dark is light)', () {
      expect(SemanticColors.lightTokens.textPrimary != SemanticColors.darkTokens.textPrimary, isTrue);
    });
  });

  group('AppSpacing / AppRadius tokens', () {
    test('spacing follows 4/8/12/16/20/24/32/48 scale', () {
      expect(AppSpacing.xxs, 4);
      expect(AppSpacing.xs, 8);
      expect(AppSpacing.s, 12);
      expect(AppSpacing.m, 16);
      expect(AppSpacing.l, 20);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
      expect(AppSpacing.huge, 48);
    });

    test('radius scale: 8 for buttons, 16 for cards (canonical)', () {
      expect(AppRadius.s, 8);
      expect(AppRadius.l, 16);
    });
  });
}
