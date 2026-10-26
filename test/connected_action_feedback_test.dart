import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/features/availability/domain/provider_setup.dart';
import 'package:rental_app_demo/screens/connected_booking_evidence_screen.dart';
import 'package:rental_app_demo/screens/connected_booking_review_screen.dart';
import 'package:rental_app_demo/screens/connected_provider_setup_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_evidence_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_review_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';
import 'package:rental_app_demo/widgets/connected_action_feedback.dart';

void main() {
  Finder contentScroll() => find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

  testWidgets(
      'review waits once, preserves edited draft on failure and keeps result visible',
      (tester) async {
    final delayed = Completer<BookingReviewRecord>();
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedBookingReviewScreen(
        bookingId: 'booking-1',
        isOwner: true,
        load: (_) async => const BookingReviewRecord(
            bookingId: 'booking-1', rating: 4, comment: 'Original review'),
        save: (id, rating, comment) {
          saves++;
          return saves == 1
              ? delayed.future
              : Future.value(BookingReviewRecord(
                  bookingId: id, rating: rating, comment: comment));
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await tester.enterText(find.byType(TextField), 'My updated review');
    await tester.tap(find.text('Update rating'));
    await tester.pump();
    expect(find.text('Saving your review'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    final savingButton = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Saving rating…'), matching: find.byType(FilledButton)));
    expect(savingButton.onPressed, isNull);
    expect(saves, 1);
    delayed.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Review not confirmed'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My updated review');
    expect(find.text('5 / 5 stars'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Review not confirmed'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Update rating'), 120,
        scrollable: contentScroll());
    await tester.tap(find.text('Update rating'));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(find.text('Your review was saved.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Your review was saved.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'A new unsaved change');
    await tester.pump();
    expect(find.text('Your review was saved.'), findsNothing);
  });

  testWidgets(
      'availability shows delayed progress and persistent acknowledged success',
      (tester) async {
    final delayed = Completer<void>();
    var saves = 0;
    var selected = <String>{};
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedProviderSetupScreen(
        load: () async => ProviderSetupData(
          services: const [
            ProviderServiceItem(id: 'type-1', name: 'Deep cleaning')
          ],
          selectedServiceIds: selected,
          slots: const [],
          unavailableDates: const {},
        ),
        saveServices: (ids) async {
          saves++;
          await delayed.future;
          selected = Set.of(ids);
        },
        addSlot: (_, __, ___) async {},
        removeSlot: (_) async {},
        addUnavailableDate: (_) async {},
        removeUnavailableDate: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-Deep cleaning')));
    await tester.pump();
    await tester.tap(find.text('Save service types'));
    await tester.pump();
    expect(find.text('Saving cleaning services'), findsOneWidget);
    expect(saves, 1);
    final saveButton = tester.widget<FilledButton>(find.ancestor(
        of: find.text('Save service types'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton)));
    expect(saveButton.onPressed, isNull);
    delayed.complete();
    await tester.pumpAndSettle();
    expect(find.text('Changes saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Changes saved'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Deep cleaning'), 100,
        scrollable: contentScroll());
    await tester.tap(find.byKey(const Key('service-Deep cleaning')));
    await tester.pump();
    expect(find.text('Changes saved'), findsNothing);
  });

  testWidgets(
      'photo upload locks repeated action and acknowledges the saved photo',
      (tester) async {
    final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAXSURBVBhXY2BgaPjffu71fwYwwdDwHwBQbAl96byCRgAAAABJRU5ErkJggg==');
    final delayed = Completer<void>();
    String? path;
    var uploads = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ConnectedBookingEvidenceScreen(
        bookingId: 'booking-1',
        isProvider: true,
        status: 'In Progress',
        load: (_) async => BookingEvidenceRecord(
            bookingId: 'booking-1', beforePath: path, remarks: ''),
        download: (_) async => png,
        upload: (_, __, ___, ____, _____) async {
          uploads++;
          await delayed.future;
          path = 'booking-1/before.png';
          return path!;
        },
        saveRemarks: (_, __) async {},
        complete: (_) async {},
        checkStatus: (_) async => 'In Progress',
        pickPhoto: () async => png,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add before photo'));
    await tester.pump();
    expect(find.text('Uploading and validating before photo'), findsOneWidget);
    expect(uploads, 1);
    final uploadButton = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Add before photo'),
        matching:
            find.byWidgetPredicate((widget) => widget is OutlinedButton)));
    expect(uploadButton.onPressed, isNull);
    delayed.complete();
    await tester.pumpAndSettle();
    expect(find.text('Before photo saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Before photo saved'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
      'persistent feedback and recovery action fit above keyboard at 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: ConnectedActionFeedbackFrame(
          notice: const ConnectedActionNotice(
              ConnectedActionState.error,
              'Change not confirmed',
              'Your draft is kept. Check your connection and review the current record before trying again.'),
          actionLabel: 'Check record',
          onAction: () => retried = true,
          child: ListView(children: const [TextField()]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Check record'), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Check record'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
}
