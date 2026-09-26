// lib/screens/chat_list_screen.dart
// Lists all conversations for the current user.
// Tap a conversation → opens the chat screen.
//
// Round 9 polish (CL1-CL6):
//   CL1 Theme colors throughout (sem.* + AppColors.*)
//   CL2 intl.DateFormat for time-ago labels
//   CL3 Search bar to filter conversations by counterpart name
//   CL4 "Unread only" filter chip in app bar
//   CL5 "Pinned" conversations float to top (first 2, demo only)
//   CL6 Total unread badge in app bar
//
// Round 14 fix: wrap the body in AnimatedBuilder so the list rebuilds
// when a new message is sent (was reading store.conversations directly).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/message.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _unreadOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSessionAccess.of(context);
    final me = session.displayName.isEmpty ? 'Owner' : session.displayName;
    final isProvider = session.role == UserRole.provider;
    // Round 14 fix: wrap the body in AnimatedBuilder so the list rebuilds
    // when a new message is sent or read state changes.
    final store = AppProviders.of(context).messageStore;
    return AnimatedBuilder(
      animation: store,
      builder: (ctx, _) {
        final all = store.conversations
            .where((c) => c.participantA == me || c.participantB == me)
            .toList();

        // Apply search + unread filters
        final filtered = all.where((c) {
          if (_unreadOnly && c.unreadCount == 0) return false;
          if (_searchQuery.isEmpty) return true;
          final counterpart = c.participantA == me ? c.participantB : c.participantA;
          return counterpart.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        // CL5: Pinned conversations float to top (first 2 by lastTimestamp).
        // (Demo only — no real pin storage; uses mock logic.)
        final pinned = [...filtered]..sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));
        final pinnedTop = pinned.take(2).toList();
        final rest = pinned.skip(2).toList();

        final totalUnread = all.fold<int>(0, (a, c) => a + c.unreadCount);

        return _buildScaffold(
          ctx: ctx,
          me: me,
          isProvider: isProvider,
          all: all,
          filtered: filtered,
          pinnedTop: pinnedTop,
          rest: rest,
          totalUnread: totalUnread,
        );
      },
    );
  }

  Widget _buildScaffold({
    required BuildContext ctx,
    required String me,
    required bool isProvider,
    required List<Conversation> all,
    required List<Conversation> filtered,
    required List<Conversation> pinnedTop,
    required List<Conversation> rest,
    required int totalUnread,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Messages'),
            if (totalUnread > 0) ...[
              const SizedBox(width: 8),
              _UnreadBadge(count: totalUnread),
            ],
          ],
        ),
        actions: [
          // CL4: Unread-only filter chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: FilterChip(
              selected: _unreadOnly,
              label: const Text('Unread'),
              avatar: Icon(
                _unreadOnly ? Icons.mark_email_read : Icons.mark_email_unread,
                size: 16,
                color: _unreadOnly ? Colors.white : AppColors.primary,
              ),
              selectedColor: AppColors.primary,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _unreadOnly ? Colors.white : AppColors.primary,
              ),
              onSelected: (v) => setState(() => _unreadOnly = v),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // CL3: Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: SemanticColors.of(context).textTertiary,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  child: Icon(
                    Icons.search,
                    size: 18,
                    color: SemanticColors.of(context).textSecondary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyChat(
                    isFiltered: _searchQuery.isNotEmpty || _unreadOnly,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: pinnedTop.length + rest.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 76),
                    itemBuilder: (ctx, i) {
                      final isPinned = i < pinnedTop.length;
                      final c = isPinned ? pinnedTop[i] : rest[i - pinnedTop.length];
                      final counterpart =
                          c.participantA == me ? c.participantB : c.participantA;
                      return _ConversationTile(
                        conversation: c,
                        counterpart: counterpart,
                        isProvider: isProvider,
                        isPinned: isPinned,
                        onTap: () {
                          Haptics.selection();
                          Navigator.of(ctx).push(MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: c.id,
                              counterpart: counterpart,
                            ),
                          ));
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.counterpart,
    required this.isProvider,
    required this.isPinned,
    required this.onTap,
  });
  final Conversation conversation;
  final String counterpart;
  final bool isProvider;
  final bool isPinned;
  final VoidCallback onTap;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  String _formatTime(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    // CL2: intl for older messages
    return DateFormat('d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    final hasUnread = conversation.unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isProvider ? AppColors.primarySurface : AppColors.secondarySurface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(counterpart),
                  style: TextStyle(
                    color: isProvider ? AppColors.primary : AppColors.secondaryDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // CL5: Pinned indicator
                            if (isPinned) ...[
                              Icon(
                                Icons.push_pin,
                                size: 12,
                                color: sem.textTertiary,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                counterpart,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: sem.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(conversation.lastTimestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: hasUnread
                              ? AppColors.primary
                              : sem.textTertiary,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.property,
                    style: TextStyle(fontSize: 11, color: sem.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage.isEmpty
                              ? 'No messages yet'
                              : conversation.lastMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasUnread
                                ? sem.textPrimary
                                : sem.textSecondary,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({this.isFiltered = false});
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.filter_alt_off_outlined : Icons.chat_bubble_outline,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'No matches' : 'No conversations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: sem.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Try a different search or filter.'
                  : 'Open a booking and tap "Message" to start a chat.',
              style: TextStyle(fontSize: 13, color: sem.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
