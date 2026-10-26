import 'package:flutter/material.dart';

import '../widgets/connected_state_panel.dart';
import '../widgets/booking_activity_tile.dart';
import '../services/backend/cursor_feed.dart';
import '../widgets/connected_paged_list.dart';
import '../widgets/connected_route_lifecycle.dart';

/// A booking-scoped history view with an explicit pending, empty, failed and
/// loaded state. The server remains responsible for participant access.
class ConnectedBookingHistorySheet extends StatefulWidget {
  const ConnectedBookingHistorySheet({
    super.key,
    required this.bookingId,
    this.load,
    this.pagedHistory,
  }) : assert(load != null || pagedHistory != null);

  final String bookingId;
  final Future<List<Map<String, dynamic>>> Function(String)? load;
  final CursorFeed<Map<String, dynamic>>? pagedHistory;

  @override
  State<ConnectedBookingHistorySheet> createState() =>
      _ConnectedBookingHistorySheetState();
}

class _ConnectedBookingHistorySheetState
    extends State<ConnectedBookingHistorySheet>
    with ConnectedRouteLifecycle<ConnectedBookingHistorySheet> {
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.load?.call(widget.bookingId) ?? Future.value([]);
  }

  @override
  void onConnectedRouteActivity(bool active) =>
      widget.pagedHistory?.setActive(active);

  void _retry() => setState(() {
        widget.pagedHistory?.refresh();
        _history = widget.load?.call(widget.bookingId) ?? Future.value([]);
      });

  @override
  void dispose() {
    widget.pagedHistory?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4)))),
                Row(children: [
                  const Expanded(
                      child: Text('Booking activity',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700))),
                  if (Navigator.of(context).canPop())
                    IconButton(
                        tooltip: 'Close activity',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context)),
                ]),
                const Text('Latest updates first · Malaysia time'),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.pagedHistory != null
                      ? ConnectedPagedList<Map<String, dynamic>>(
                          feed: widget.pagedHistory!,
                          emptyTitle: 'No status changes yet',
                          emptyMessage:
                              'Updates to this booking will appear here.',
                          errorTitle: 'Could not load status history',
                          moreLabel: 'Load older changes',
                          showCount: false,
                          itemBuilder: (event) => BookingActivityTile(
                            event: event,
                            isLatest: identical(
                                event, widget.pagedHistory!.items.firstOrNull),
                            isLast: identical(
                                event, widget.pagedHistory!.items.lastOrNull),
                          ),
                        )
                      : FutureBuilder<List<Map<String, dynamic>>>(
                          future: _history,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return ConnectedStatePanel(
                                state: ConnectedViewState.error,
                                title: 'Could not load status history',
                                message: 'Check your connection and try again.',
                                actionLabel: 'Retry',
                                onAction: _retry,
                              );
                            }
                            if (!snapshot.hasData) {
                              return const ConnectedStatePanel(
                                state: ConnectedViewState.loading,
                                title: 'Loading status history',
                                message: 'Checking changes to this booking.',
                              );
                            }
                            final events =
                                List<Map<String, dynamic>>.from(snapshot.data!)
                                  ..sort((a, b) {
                                    final timeA = DateTime.tryParse(
                                        a['changed_at'] as String? ?? '');
                                    final timeB = DateTime.tryParse(
                                        b['changed_at'] as String? ?? '');
                                    final byTime = (timeB ?? DateTime(1970))
                                        .compareTo(timeA ?? DateTime(1970));
                                    return byTime != 0
                                        ? byTime
                                        : (b['status_history_id']?.toString() ??
                                                '')
                                            .compareTo(a['status_history_id']
                                                    ?.toString() ??
                                                '');
                                  });
                            if (events.isEmpty) {
                              return const ConnectedStatePanel(
                                state: ConnectedViewState.empty,
                                title: 'No status changes yet',
                                message:
                                    'Updates to this booking will appear here.',
                              );
                            }
                            return ListView.builder(
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                return BookingActivityTile(
                                    event: event,
                                    isLatest: index == 0,
                                    isLast: index == events.length - 1);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
}
