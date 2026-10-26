// test/theme_test.dart
// Verifies the light + dark theme tokens are well-formed and contrasting.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/section_header.dart';

void main() {
  double contrast(Color a, Color b) {
    final lighter = a.computeLuminance() > b.computeLuminance()
        ? a.computeLuminance()
        : b.computeLuminance();
    final darker = a.computeLuminance() < b.computeLuminance()
        ? a.computeLuminance()
        : b.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('body and hint text retain at least 4.5:1 on both themes', () {
    for (final colors in [
      SemanticColors.lightTokens,
      SemanticColors.darkTokens,
    ]) {
      for (final foreground in [
        colors.textPrimary,
        colors.textSecondary,
        colors.textTertiary,
      ]) {
        expect(contrast(foreground, colors.surface), greaterThanOrEqualTo(4.5));
        expect(
            contrast(foreground, colors.background), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('standard buttons request a 48dp minimum touch size', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        final size = style.minimumSize!.resolve({})!;
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    }
  });

  testWidgets('section headings remain readable on a dark card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(
        body: Card(
          child: SectionHeader(title: 'Service', subtitle: 'What was ordered'),
        ),
      ),
    ));
    final title = tester.widget<Text>(find.text('Service'));
    final subtitle = tester.widget<Text>(find.text('What was ordered'));
    expect(title.style?.color, SemanticColors.darkTokens.textPrimary);
    expect(subtitle.style?.color, SemanticColors.darkTokens.textSecondary);
  });

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

    test('primary color is workspace navy', () {
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.primary, const Color(0xFF172F67));
    });

    test('secondary color is sky blue', () {
      expect(theme.colorScheme.secondary, AppColors.secondary);
      expect(theme.colorScheme.secondary, const Color(0xFF4F9FD5));
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
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0B1422));
    });

    test('primary uses brighter sky blue for dark-bg contrast', () {
      expect(theme.colorScheme.primary, AppColors.primaryLighter);
      expect(theme.colorScheme.primary, const Color(0xFFB5DDF7));
    });

    test('dark primary button keeps readable text contrast', () {
      final button = theme.filledButtonTheme.style!;
      final background = button.backgroundColor!.resolve({})!;
      final foreground = button.foregroundColor!.resolve({})!;
      final lighter =
          background.computeLuminance() > foreground.computeLuminance()
              ? background.computeLuminance()
              : foreground.computeLuminance();
      final darker =
          background.computeLuminance() < foreground.computeLuminance()
              ? background.computeLuminance()
              : foreground.computeLuminance();
      expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
    });

    test('card theme has 16dp radius (canonical)', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      final radius = shape.borderRadius as BorderRadius;
      expect(radius.topLeft.x, AppRadius.l);
    });

    test('dark surfaces have distinct depth and readable body text', () {
      const s = SemanticColors.darkTokens;
      expect(s.background, isNot(s.surface));
      expect(s.surface, isNot(s.surfaceAlt));
      double contrast(Color a, Color b) {
        final first = a.computeLuminance();
        final second = b.computeLuminance();
        final light = first > second ? first : second;
        final dark = first > second ? second : first;
        return (light + 0.05) / (dark + 0.05);
      }

      expect(contrast(s.textPrimary, s.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(s.textSecondary, s.surface), greaterThanOrEqualTo(4.5));
      expect(contrast(theme.colorScheme.primary, s.surface),
          greaterThanOrEqualTo(4.5));
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
      expect(
          SemanticColors.lightTokens.textPrimary !=
              SemanticColors.darkTokens.textPrimary,
          isTrue);
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
