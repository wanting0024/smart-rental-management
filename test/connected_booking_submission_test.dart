import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/screens/connected_booking_request_screen.dart';
import 'package:rental_app_demo/services/backend/supabase_booking_repository.dart';
import 'package:rental_app_demo/services/backend/supabase_owner_repository.dart';

void main() {
  testWidgets(
      'Owner retries unchanged notes safely and edits start a new request',
      (tester) async {
    final submittedTokens = <String>[];
    num? submittedAmount;
    String? submittedBasis;
    final submittedNotes = <String>[];
    DateTime? submittedStart;
    DateTime? submittedEnd;
    var submissions = 0;
    final firstSubmission = Completer<void>();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
          builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => ConnectedBookingRequestScreen(
                      loadProperties: () async => [
                        {
                          'property_id': 'property-1',
                          'unit_name': 'Unit A-12',
                          'building_name': 'Menara Suria',
                        },
                      ],
                      loadServiceTypes: () async => [
                        {
                          'service_type_id': 'service-1',
                          'name': 'Standard cleaning'
                        },
                      ],
                      findEligible: ({
                        required propertyId,
                        required serviceTypeId,
                        required start,
                        required end,
                      }) async =>
                          const [
                        EligibleProviderItem(
                          providerId: 'provider-1',
                          serviceArea: 'Petaling Jaya',
                          hourlyRate: 40,
                          dailyRate: 280,
                          completedJobCount: 2,
                          quoteBasis: 'hourly',
                          quotedAmount: 80,
                        ),
                      ],
                      createPending: ({
                        required clientRequestId,
                        required providerId,
                        required propertyId,
                        required serviceTypeId,
                        required start,
                        required end,
                        required expectedAmount,
                        required expectedBasis,
                        required instructions,
                      }) async {
                        submissions++;
                        submittedTokens.add(clientRequestId);
                        submittedNotes.add(instructions);
                        submittedAmount = expectedAmount;
                        submittedBasis = expectedBasis;
                        submittedStart = start;
                        submittedEnd = end;
                        if (submissions <= 2) {
                          if (submissions == 1) await firstSubmission.future;
                          throw StateError('Simulated network timeout');
                        }
                        return const BookingCreationOutcome(
                          bookingId: 'booking-1',
                          reused: false,
                          quotedAmount: 80,
                          quoteBasis: 'hourly',
                          quoteCurrency: 'MYR',
                        );
                      },
                      findCreatedBooking: (_) async => null,
                    ),
                  )),
                  child: const Text('Open request'),
                ),
              )),
    ));
    await tester.tap(find.text('Open request'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit A-12, Menara Suria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard cleaning').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select service date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Find eligible providers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find eligible providers'));
    await tester.pumpAndSettle();
    // The result may be below a short test viewport; scroll it into view.
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quoted price · RM 80.00'), findsOneWidget);
    await tester.tap(find.text('Select and review'));
    await tester.pumpAndSettle();
    await tester.fling(
      find.byType(ListView),
      const Offset(0, -1200),
      2000,
    );
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Total quoted amount: RM 80.00'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('booking-instructions')));
    await tester.enterText(
        find.byKey(const Key('booking-instructions')), 'Use side gate.');
    await tester
        .ensureVisible(find.byKey(const Key('booking-additional-tasks')));
    await tester.enterText(find.byKey(const Key('booking-additional-tasks')),
        'Clean inside the oven?');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Submit Pending request'));
    await tester.tap(find.text('Submit Pending request'));
    await tester.pump();
    expect(find.text('Sending cleaning request'), findsOneWidget);
    expect(submissions, 1);
    expect(
        find.byWidgetPredicate(
            (widget) => widget is AbsorbPointer && widget.absorbing),
        findsWidgets);
    firstSubmission.complete();
    await tester.pumpAndSettle();

    expect(submissions, 1);
    expect(find.byType(ConnectedBookingRequestScreen), findsOneWidget);
    await tester.fling(
      find.byType(ListView),
      const Offset(0, -1200),
      2000,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Pending request'));
    await tester.pumpAndSettle();

    expect(submissions, 2);
    expect(submittedTokens[0], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(submittedTokens[1], submittedTokens[0]);
    expect(submittedAmount, 80);
    expect(submittedBasis, 'hourly');
    expect(submittedEnd!.difference(submittedStart!), const Duration(hours: 2));
    expect(submittedNotes[0], submittedNotes[1]);
    expect(submittedNotes[0], contains('Use side gate.'));
    expect(submittedNotes[0], contains('not included in the quote'));
    expect(submittedNotes[0], contains('Clean inside the oven?'));
    await tester
        .ensureVisible(find.byKey(const Key('booking-additional-tasks')));
    await tester.enterText(find.byKey(const Key('booking-additional-tasks')),
        'Clean inside the fridge?');
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Submit Pending request'));
    await tester.tap(find.text('Submit Pending request'));
    await tester.pumpAndSettle();
    expect(submissions, 3);
    expect(submittedTokens[2], isNot(submittedTokens[1]));
    expect(submittedNotes[2], contains('Clean inside the fridge?'));
    expect(submittedNotes[2], isNot(contains('Clean inside the oven?')));
    expect(find.text('Open request'), findsOneWidget);
  });

  testWidgets('lost booking response is verified before another submission',
      (tester) async {
    var submissions = 0;
    String? submittedToken;
    String? checkedToken;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ConnectedBookingRequestScreen(
                loadProperties: () async => [
                  {
                    'property_id': 'property-1',
                    'unit_name': 'Unit A-12',
                    'building_name': 'Menara Suria',
                  },
                ],
                loadServiceTypes: () async => [
                  {'service_type_id': 'service-1', 'name': 'Standard cleaning'},
                ],
                findEligible: ({
                  required propertyId,
                  required serviceTypeId,
                  required start,
                  required end,
                }) async =>
                    const [
                  EligibleProviderItem(
                    providerId: 'provider-1',
                    serviceArea: 'Petaling Jaya',
                    hourlyRate: 40,
                    completedJobCount: 2,
                    quoteBasis: 'hourly',
                    quotedAmount: 80,
                  ),
                ],
                createPending: ({
                  required clientRequestId,
                  required providerId,
                  required propertyId,
                  required serviceTypeId,
                  required start,
                  required end,
                  required expectedAmount,
                  required expectedBasis,
                  required instructions,
                }) async {
                  submissions++;
                  submittedToken = clientRequestId;
                  throw StateError('response lost');
                },
                findCreatedBooking: (token) async {
                  checkedToken = token;
                  return 'booking-1';
                },
              ),
            )),
            child: const Text('Open request'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open request'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unit A-12, Menara Suria').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard cleaning').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select service date'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select time').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select time').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Find eligible providers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find eligible providers'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select and review'));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -1200), 2000);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Pending request'));
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(checkedToken, submittedToken);
    expect(find.text('Open request'), findsOneWidget);
  });
}
