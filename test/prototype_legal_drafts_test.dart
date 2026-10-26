import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/content/prototype_legal_drafts.dart';
import 'package:rental_app_demo/screens/about_screen.dart';
import 'package:rental_app_demo/screens/prototype_legal_draft_screen.dart';
import 'package:rental_app_demo/services/prototype_support_store.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/Inter.ttf')))
        .load();
  });

  test('draft visibility is explicit and fails closed for unknown environments',
      () {
    expect(canPreviewLegalDrafts('staging'), isTrue);
    expect(canPreviewLegalDrafts(null), isFalse);
    expect(canPreviewLegalDrafts(null, localPreview: true), isTrue);
    expect(canPreviewLegalDrafts('local', localPreview: true), isTrue);
    for (final environment in ['production', 'Production', 'unknown', '']) {
      expect(canPreviewLegalDrafts(environment, localPreview: true), isFalse);
    }
  });

  test('user copies retain draft status without the developer checklist', () {
    for (final kind in LegalDraftKind.values) {
      final draft = PrototypeLegalDraft.forKind(kind);
      expect(draft.copyText, contains('DRAFT — NOT PUBLISHED'));
      expect(draft.copyText, contains(PrototypeLegalDraft.version));
      expect(draft.copyText, contains('No effective date or legal acceptance'));
      for (final item in PrototypeLegalDraft.releaseChecklist) {
        expect(draft.copyText, isNot(contains(item)));
      }
      expect(draft.copyText, isNot(contains('implementation review')));
      expect(draft.copyText, isNot(contains('Before public launch')));
      expect(() => draft.sections.clear(), throwsUnsupportedError);
    }
  });

  test('content distinguishes stored data from simulation and missing services',
      () {
    final privacy = PrototypeLegalDraft.privacy.copyText;
    expect(privacy, contains('Signing out does not delete cloud'));
    expect(privacy, contains('not end-to-end encrypted'));
    expect(privacy,
        contains('not a channel for requesting access to or deletion'));
    expect(privacy, contains('do not assume it is hidden until acceptance'));
    expect(privacy, contains('browser session storage'));
    expect(privacy, contains('Account deletion and data export are not yet'));
    expect(privacy, contains('only in memory'));
    expect(privacy, contains('Selecting a photo starts its upload'));
    expect(privacy, contains('does not upload your whole gallery'));
    final terms = PrototypeLegalDraft.terms.copyText;
    expect(terms, contains('Pending request does not reserve a slot'));
    expect(terms, contains('different duration requires a new priced request'));
    expect(
        terms,
        contains(
            'policy for starting early or late have not been established'));
    expect(terms, contains('not work automatically included in the quote'));
    expect(terms, contains('not money received'));
    expect(terms, contains('timeout alone does not prove failure or success'));
  });

  for (final kind in LegalDraftKind.values) {
    testWidgets('original About opens ${kind.name} draft and returns',
        (tester) async {
      final draft = PrototypeLegalDraft.forKind(kind);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: const AboutScreen(environmentLabel: 'staging')));
      await tester.ensureVisible(find.text(draft.title));
      await tester.tap(find.text(draft.title));
      await tester.pumpAndSettle();
      expect(find.byType(PrototypeLegalDraftScreen), findsOneWidget);
      expect(find.text(PrototypeLegalDraft.status), findsOneWidget);
      expect(find.text(draft.notice), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('I agree'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('About & help'), findsOneWidget);
    });

    testWidgets('copy ${kind.name} includes warnings and complete sections',
        (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(MaterialApp(
          home: PrototypeLegalDraftScreen(
              kind: kind, environmentLabel: 'staging')));
      await tester.ensureVisible(find.text('Copy review draft'));
      await tester.tap(find.text('Copy review draft'));
      await tester.pumpAndSettle();
      expect(copied, PrototypeLegalDraft.forKind(kind).copyText);
      expect(find.text('Draft copied with its unpublished status.'),
          findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('${kind.name} at 320px / 200% text, dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                  size: Size(320, 568), textScaler: TextScaler.linear(2)),
              child: child!),
          home: PrototypeLegalDraftScreen(
              kind: kind, environmentLabel: 'staging'),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final last =
            find.text(PrototypeLegalDraft.forKind(kind).sections.last.title);
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Copy review draft'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final environment in ['production', 'unknown']) {
    testWidgets('$environment cannot navigate or directly display a draft',
        (tester) async {
      final store = PrototypeSupportStore(enabled: true)..bindSession('test');
      addTearDown(store.dispose);
      await tester.pumpWidget(MaterialApp(
          home: AboutScreen(
              environmentLabel: environment, prototypeSupport: store)));
      expect(
          find.text('Create and track simulated test requests'), findsNothing);
      await tester.ensureVisible(find.text('Terms of service'));
      await tester.tap(find.text('Terms of service'));
      await tester.pumpAndSettle();
      expect(find.byType(PrototypeLegalDraftScreen), findsNothing);
      expect(find.textContaining('not been published as final terms'),
          findsOneWidget);
      // Dispose the navigation stack before testing a direct entry point.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(
          home: PrototypeLegalDraftScreen(
              kind: LegalDraftKind.privacy,
              environmentLabel: environment,
              localPreview: true)));
      await tester.pumpAndSettle();
      expect(find.text('Copy review draft'), findsNothing);
      expect(find.textContaining('Not published yet.'), findsOneWidget);
      expect(find.text(PrototypeLegalDraft.privacy.sections.first.body),
          findsNothing);
    });
  }

  testWidgets('local signed-in preview can read drafts without a backend',
      (tester) async {
    final store = PrototypeSupportStore(enabled: true)..bindSession('test');
    addTearDown(store.dispose);
    await tester
        .pumpWidget(MaterialApp(home: AboutScreen(prototypeSupport: store)));
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.text(PrototypeLegalDraft.status), findsOneWidget);
  });

  testWidgets(
      'help explains new message, revision, uncertain save and data logic',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    await tester.ensureVisible(find.text('Help center'));
    await tester.tap(find.text('Help center'));
    await tester.pumpAndSettle();
    final article = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(article.data, contains('about every 30 seconds'));
    expect(article.data, contains('Opening the list does not clear a thread'));
    expect(article.data,
        contains('different duration needs a new priced request'));
    expect(article.data, contains('timeout does not prove'));
    expect(article.data, contains('not cloud bookings, photos or messages'));
    expect(article.data,
        contains('Self-service account deletion and export are not complete'));
  });
}
