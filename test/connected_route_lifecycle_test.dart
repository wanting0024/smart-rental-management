import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rental_app_demo/widgets/connected_route_lifecycle.dart';
import 'package:rental_app_demo/widgets/lifecycle_stream_builder.dart';
import 'package:rental_app_demo/screens/connected_booking_messages_screen.dart';
import 'package:rental_app_demo/services/backend/cursor_feed.dart';
import 'package:rental_app_demo/services/backend/supabase_message_repository.dart';
import 'package:rental_app_demo/theme/app_theme.dart';

class Probe extends StatefulWidget {
  const Probe(this.changed, {super.key});
  final ValueChanged<bool> changed;
  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> with ConnectedRouteLifecycle<Probe> {
  @override
  void onConnectedRouteActivity(bool active) => widget.changed(active);
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Current page'));
}

void main() {
  testWidgets('pushed page and modal suspend the route below, pop resumes once',
      (tester) async {
    final observer = RouteObserver<ModalRoute<dynamic>>();
    final states = <bool>[];
    await tester.pumpWidget(
      ConnectedRouteScope(
        observer: observer,
        child: MaterialApp(
          navigatorObservers: [observer],
          home: Probe(states.add),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(states, [true]);
    final context = tester.element(find.text('Current page'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Details')),
      ),
    );
    await tester.pumpAndSettle();
    expect(states, [true, false]);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(states, [true, false, true]);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Text('History sheet'),
    );
    await tester.pumpAndSettle();
    expect(states.last, isFalse);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(states, [true, false, true, false, true]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'background suspends without drawing a frame, resume waits for visibility',
      (tester) async {
    final states = <bool>[];
    await tester.pumpWidget(MaterialApp(home: Probe(states.add)));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(states, [true, false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(states, [true, false]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(states, [true, false, true]);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(states, [true, false, true]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets(
      'stream replacement waits for cancel and never reuses old Accepted snapshot',
      (tester) async {
    final activity = ValueNotifier(true);
    final cancel = Completer<void>();
    var opens = 0;
    final old = StreamController<String>(onCancel: () => cancel.future);
    final fresh = StreamController<String>();
    addTearDown(old.close);
    addTearDown(fresh.close);
    Stream<String> open() => ++opens == 1 ? old.stream : fresh.stream;
    await tester.pumpWidget(
      MaterialApp(
        home: LifecycleStreamBuilder<String>(
          activity: activity,
          open: open,
          builder: (_, snapshot) => Text(snapshot.data ?? 'Checking'),
        ),
      ),
    );
    old.add('Accepted');
    await tester.pumpAndSettle();
    expect(find.text('Accepted'), findsOneWidget);
    activity.value = false;
    activity.value = true;
    await tester.pump();
    expect(opens, 1);
    expect(find.text('Accepted'), findsNothing);
    cancel.complete();
    await tester.pump();
    expect(opens, 2);
    fresh.add('Completed');
    await tester.pumpAndSettle();
    expect(find.text('Completed'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    activity.dispose();
  });

  testWidgets(
      'chat keeps draft after background and checks fresh status before sending',
      (tester) async {
    final statuses = <StreamController<String?>>[];
    var activeStatuses = 0;
    var messageReads = 0;
    final messages = CursorFeed<BookingMessage>(
      active: false,
      loadPage: (_) async {
        messageReads++;
        return const CursorPage(items: []);
      },
      idOf: (row) => row.id,
      compare: (_, __) => 0,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ConnectedBookingMessagesScreen(
          bookingId: 'booking',
          currentUserId: 'owner',
          isProvider: false,
          pagedMessages: messages,
          bookingStatus: () {
            final controller = StreamController<String?>(
              onListen: () => activeStatuses++,
              onCancel: () async {
                activeStatuses--;
              },
            );
            statuses.add(controller);
            addTearDown(controller.close);
            return controller.stream;
          },
          send: (_, __) async {},
          wasSent: (_, __) async => false,
        ),
      ),
    );
    await tester.pump();
    statuses.single.add('Accepted');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Keep the gate instructions',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.idle();
    expect(messages.active, isFalse);
    expect(activeStatuses, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(statuses.length, 2);
    expect(find.byTooltip('Send message'), findsNothing);
    expect(find.text('Checking the latest booking status…'), findsOneWidget);
    statuses.last.add('Accepted');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep the gate instructions',
    );
    expect(messageReads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
    expect(activeStatuses, 0);
  });
}
