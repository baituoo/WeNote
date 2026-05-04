import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import 'session_tile.dart';

class SessionList extends ConsumerStatefulWidget {
  const SessionList({super.key});

  @override
  ConsumerState<SessionList> createState() => _SessionListState();
}

class _SessionListState extends ConsumerState<SessionList> {
  final _searchController = TextEditingController();
  String _query = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _query = value;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _debouncedQuery = _query);
        ref.read(activeSearchQueryProvider.notifier).state = _query;
      }
    });
    // Immediately clear debounced results when input is cleared
    if (value.isEmpty) {
      _debounceTimer?.cancel();
      setState(() => _debouncedQuery = '');
      ref.read(activeSearchQueryProvider.notifier).state = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionNotifierProvider);
    final sessions = sessionState.sessions;
    final currentId = ref.watch(currentSessionIdProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final loc = ref.loc;

    // When searching, use database search; otherwise show all sessions
    final searchAsync = _debouncedQuery.isNotEmpty
        ? ref.watch(searchedSessionsProvider(_debouncedQuery))
        : null;
    final searchLoading = searchAsync != null && searchAsync.isLoading;
    final filtered = searchAsync != null
        ? (searchAsync.valueOrNull ?? [])
        : sessions;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: loc.searchSessions,
                    prefixIcon:
                        const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _createSession(context),
                icon: Icon(Icons.add_comment_rounded,
                    color: colorScheme.primary),
                tooltip: loc.newSession,
              ),
            ],
          ),
        ),
        Expanded(
          child: searchLoading
              ? const Center(child: CircularProgressIndicator())
              : sessionState.loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                _debouncedQuery.isNotEmpty
                                    ? loc.noMatching
                                    : loc.noConversations,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                              ),
                              if (_debouncedQuery.isEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  loc.clickToStart,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final session = filtered[index];
                            final lastMsgAsync =
                                ref.watch(lastMessageProvider(session.id));
                            final matchCntAsync = _debouncedQuery.isNotEmpty
                                ? ref.watch(matchCountProvider(session.id))
                                : null;
                            final lastMatchAsync = _debouncedQuery.isNotEmpty
                                ? ref.watch(lastMatchingMessageProvider(session.id))
                                : null;
                            return SessionTile(
                              session: session,
                              lastMessage: lastMsgAsync.valueOrNull,
                              noMessagesText: loc.noMessages,
                              isActive: session.id == currentId,
                              loc: loc,
                              searchQuery: _debouncedQuery,
                              matchCount: matchCntAsync?.valueOrNull ?? 0,
                              lastMatchingMessage:
                                  lastMatchAsync?.valueOrNull,
                              onTap: () {
                                ref
                                    .read(currentSessionIdProvider.notifier)
                                    .state = session.id;
                                ref
                                    .read(messageNotifierProvider.notifier)
                                    .loadMessages(session.id);
                              },
                              onContextMenu: (position) =>
                                  _showSessionMenu(context, session, position),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  void _createSession(BuildContext context) {
    final loc = ref.loc;
    final controller = TextEditingController();

    void doCreate() {
      final name = controller.text.trim();
      if (name.isNotEmpty) {
        _addSession(name);
        Navigator.of(context).pop();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.newSession),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (_) => doCreate(),
          decoration: InputDecoration(
            hintText: loc.sessionName,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: doCreate,
            child: Text(loc.create),
          ),
        ],
      ),
    );
  }

  void _addSession(String name) async {
    final uuid = ref.read(uuidProvider);
    final now = DateTime.now();
    final session = Session(
      id: uuid.v4(),
      name: name,
      isPinned: false,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(sessionNotifierProvider.notifier).addSession(session);
    ref.read(currentSessionIdProvider.notifier).state = session.id;
    ref.read(messageNotifierProvider.notifier).clear();
  }

  void _showSessionMenu(
      BuildContext context, Session session, Offset position) {
    final loc = ref.loc;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem(
          onTap: () {
            ref.read(sessionNotifierProvider.notifier).updateSession(
                  session.copyWith(
                    isPinned: !session.isPinned,
                    updatedAt: DateTime.now(),
                  ),
                );
          },
          child: ListTile(
            leading: const Icon(Icons.push_pin),
            title: Text(session.isPinned ? loc.unpin : loc.pin),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: () {
            // Need to defer so the popup closes first
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _renameSession(context, session);
            });
          },
          child: ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: Text(loc.rename),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          onTap: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _deleteSession(context, session);
            });
          },
          child: ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: Colors.red),
            title: Text(loc.delete, style: TextStyle(color: Colors.red)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _renameSession(BuildContext context, Session session) {
    final loc = ref.loc;
    final controller = TextEditingController(text: session.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.renameSession),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: loc.sessionName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(sessionNotifierProvider.notifier).updateSession(
                      session.copyWith(
                        name: name,
                        updatedAt: DateTime.now(),
                      ),
                    );
                Navigator.of(ctx).pop();
              }
            },
            child: Text(loc.rename),
          ),
        ],
      ),
    );
  }

  void _deleteSession(BuildContext context, Session session) {
    final loc = ref.loc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteSession),
        content: Text(loc.deleteConfirm(session.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              await ref
                  .read(sessionNotifierProvider.notifier)
                  .deleteSession(session.id);
              final currentId = ref.read(currentSessionIdProvider);
              if (currentId == session.id) {
                ref.read(currentSessionIdProvider.notifier).state = null;
                ref.read(messageNotifierProvider.notifier).clear();
              }
              navigator.pop();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }
}
