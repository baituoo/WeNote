import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';
import 'message_bubble.dart';
import 'chat_input.dart';
import 'drop_target_area.dart';

/// Minimum gap (minutes) between two messages to show a time divider.
const _timeGapMinutes = 5;

class ChatView extends ConsumerWidget {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final messageState = ref.watch(messageNotifierProvider);
    final messages = messageState.messages;
    final colorScheme = Theme.of(context).colorScheme;
    final loc = ref.loc;

    if (session == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              loc.selectConversation,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              loc.orCreateNew,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final searchQuery = ref.watch(activeSearchQueryProvider);
    final matchingAsync = searchQuery.isNotEmpty
        ? ref.watch(matchingMessagesProvider(session.id))
        : null;
    final matchingIds = matchingAsync?.valueOrNull
            ?.map((m) => m.id)
            .toSet() ??
        <String>{};

    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      colorScheme.primary.withValues(alpha: 0.2),
                  radius: 20,
                  child: Icon(Icons.chat_bubble_outline_rounded,
                      color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    session.name,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Messages (with drag-and-drop target)
        Expanded(
          child: DropTargetArea(
            enabled: true,
            onFilesDropped: (paths) =>
                _handleDroppedFiles(context, ref, session.id, paths, loc),
            child: messageState.loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Text(
                          loc.sendFirstMessage,
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14),
                        ),
                      )
                    : _MessageList(
                        messages: messages,
                        loc: loc,
                        matchingIds: matchingIds,
                        searchQuery: searchQuery,
                        matchCount: matchingIds.length,
                        onClearSearch: () {
                          ref
                              .read(activeSearchQueryProvider.notifier)
                              .state = '';
                        },
                        onTapImage: (path) =>
                            _showImageViewer(context, path),
                        onOpenFile: (path) => _openFile(path),
                        onDelete: (msg) => ref
                            .read(messageNotifierProvider.notifier)
                            .deleteMessage(msg),
                      ),
          ),
        ),
        // Input
        ChatInput(
          onSendText: (text) => _sendMessage(ref, session.id, text),
          onSendImage: (path, name) =>
              _sendMedia(ref, session.id, 'image', path, name),
          onSendFile: (path, name) =>
              _sendMedia(ref, session.id, 'file', path, name),
          onPasteFiles: (paths) =>
              _handleDroppedFiles(context, ref, session.id, paths, loc),
        ),
      ],
    );
  }

  void _sendMessage(WidgetRef ref, String sessionId, String text) {
    final uuid = ref.read(uuidProvider);
    final now = DateTime.now();
    final message = Message(
      id: uuid.v4(),
      sessionId: sessionId,
      content: text,
      type: 'text',
      createdAt: now,
    );
    ref.read(messageNotifierProvider.notifier).addMessage(message);
  }

  void _sendMedia(WidgetRef ref, String sessionId, String type,
      String filePath, String fileName) {
    ref.read(messageNotifierProvider.notifier).addMediaMessage(
          sessionId: sessionId,
          type: type,
          filePath: filePath,
          fileName: fileName,
        );
  }

  Future<void> _handleDroppedFiles(BuildContext context, WidgetRef ref,
      String sessionId, List<String> paths, AppLoc loc) async {
    debugPrint('[Drop] _handleDroppedFiles called with ${paths.length} files');

    // Capture notifier + uuid BEFORE await — WidgetRef may be stale after.
    final messageNotifier = ref.read(messageNotifierProvider.notifier);
    final uuid = ref.read(uuidProvider);

    // Show confirmation dialog
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => SendConfirmDialog(
        filePaths: paths,
        loc: loc,
      ),
    );

    debugPrint('[Drop] Dialog result: "$text"');
    if (text == null) {
      debugPrint('[Drop] User cancelled — returning');
      return;
    }

    // Send media files
    for (final path in paths) {
      try {
        final ext = path.split('.').last.toLowerCase();
        final isImage =
            ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext);
        final type = isImage ? 'image' : 'file';
        final fileName = path.split(Platform.pathSeparator).last;

        debugPrint('[Drop] Sending $type: $fileName');
        await messageNotifier.addMediaMessage(
          sessionId: sessionId,
          type: type,
          filePath: path,
          fileName: fileName,
        );
        debugPrint('[Drop]   $fileName sent OK');
      } catch (e, stack) {
        debugPrint('[Drop]   FAILED to send $path: $e');
        debugPrint('[Drop]   Stack: $stack');
      }
    }

    // Send text message afterwards if user typed something
    if (text.trim().isNotEmpty) {
      debugPrint('[Drop] Sending text: "${text.trim()}"');
      try {
        final now = DateTime.now();
        final textMsg = Message(
          id: uuid.v4(),
          sessionId: sessionId,
          content: text.trim(),
          type: 'text',
          createdAt: now,
        );
        await messageNotifier.addMessage(textMsg);
        debugPrint('[Drop]   text sent OK');
      } catch (e) {
        debugPrint('[Drop]   FAILED to send text: $e');
      }
    }
    debugPrint('[Drop] _handleDroppedFiles done');
  }

  void _showImageViewer(BuildContext context, String imagePath) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Image viewer',
      barrierColor: Colors.transparent,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Frosted glass background
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
              ),
              // Content
              Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                body: Center(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child:
                        Image.file(File(imagePath), fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFile(String filePath) {
    Process.run('start', [filePath], runInShell: true);
  }
}

// ── Message List ───────────────────────────────────────────

class _MessageList extends StatefulWidget {
  final List<Message> messages;
  final AppLoc loc;
  final Set<String> matchingIds;
  final String searchQuery;
  final int matchCount;
  final VoidCallback onClearSearch;
  final void Function(String path)? onTapImage;
  final void Function(String path)? onOpenFile;
  final void Function(Message message)? onDelete;

  const _MessageList({
    required this.messages,
    required this.loc,
    this.matchingIds = const {},
    this.searchQuery = '',
    this.matchCount = 0,
    required this.onClearSearch,
    this.onTapImage,
    this.onOpenFile,
    this.onDelete,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final ScrollController _scrollController = ScrollController();
  int _currentMatchIdx = 0;
  bool _showMatchList = false;

  List<int> get _matchForwardIndices {
    final indices = <int>[];
    for (int i = 0; i < widget.messages.length; i++) {
      if (widget.matchingIds.contains(widget.messages[i].id)) {
        indices.add(i);
      }
    }
    return indices;
  }

  void _scrollToForwardIndex(int fwd) {
    final revIdx = widget.messages.length - 1 - fwd;
    final estimatedOffset = revIdx * 120.0;
    _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    final matches = _matchForwardIndices;
    final matchIdx = matches.indexOf(fwd);
    if (matchIdx >= 0) {
      _currentMatchIdx = matchIdx;
      setState(() {});
    }
  }

  void _navigateToMatch(int delta) {
    final matches = _matchForwardIndices;
    if (matches.isEmpty) return;

    _currentMatchIdx = (_currentMatchIdx + delta) % matches.length;
    if (_currentMatchIdx < 0) _currentMatchIdx = matches.length - 1;

    final fwd = matches[_currentMatchIdx];
    _scrollToForwardIndex(fwd);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search navigation bar
        if (widget.searchQuery.isNotEmpty)
          _SearchNavBar(
            matchCount: widget.matchCount,
            currentIdx: _currentMatchIdx,
            loc: widget.loc,
            showList: _showMatchList,
            onPrev: () => _navigateToMatch(-1),
            onNext: () => _navigateToMatch(1),
            onToggleList: () => setState(() => _showMatchList = !_showMatchList),
            onClose: widget.onClearSearch,
          ),
        // Expandable match list
        if (widget.searchQuery.isNotEmpty && _showMatchList)
          _MatchListPanel(
            messages: widget.messages,
            matchingIds: widget.matchingIds,
            searchQuery: widget.searchQuery,
            loc: widget.loc,
            currentMatchFwd: _matchForwardIndices.isNotEmpty
                ? _matchForwardIndices[_currentMatchIdx]
                : null,
            onTap: (fwd) => _scrollToForwardIndex(fwd),
          ),
        // Message list
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              // Map reversed index to forward index.
              final fwd = widget.messages.length - 1 - index;
              final message = widget.messages[fwd];

              final showDateDivider = fwd == 0 ||
                  _isDifferentDay(
                      widget.messages[fwd - 1].createdAt, message.createdAt);
              final showTimeDivider = !showDateDivider &&
                  fwd > 0 &&
                  _isTimeGap(
                      widget.messages[fwd - 1].createdAt, message.createdAt);

              final isMatch =
                  widget.matchingIds.contains(message.id);

              return Column(
                children: [
                  if (showDateDivider || showTimeDivider)
                    _SmartTimeDivider(date: message.createdAt, loc: widget.loc),
                  MessageBubble(
                    message: message,
                    loc: widget.loc,
                    isMe: true,
                    searchQuery: widget.searchQuery,
                    isSearchMatch: isMatch,
                    onTapImage: widget.onTapImage,
                    onOpenFile: widget.onOpenFile,
                    onDelete: widget.onDelete != null
                        ? () => widget.onDelete!(message)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  bool _isTimeGap(DateTime prev, DateTime curr) {
    return curr.difference(prev).inMinutes >= _timeGapMinutes;
  }
}

// ── Match List Panel ──────────────────────────────────────

class _MatchListPanel extends StatelessWidget {
  final List<Message> messages;
  final Set<String> matchingIds;
  final String searchQuery;
  final AppLoc loc;
  final int? currentMatchFwd;
  final void Function(int forwardIndex) onTap;

  const _MatchListPanel({
    required this.messages,
    required this.matchingIds,
    required this.searchQuery,
    required this.loc,
    this.currentMatchFwd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Build list of matching messages
    final matches = <Message>[];
    for (final m in messages) {
      if (matchingIds.contains(m.id)) {
        matches.add(m);
      }
    }

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          loc.noMatchesInSession,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: matches.length,
        itemBuilder: (context, index) {
          final msg = matches[index];
          final isCurrent = msg.id ==
              (currentMatchFwd != null &&
                      currentMatchFwd! < messages.length
                  ? messages[currentMatchFwd!].id
                  : null);
          final String preview;
          switch (msg.type) {
            case 'image':
              preview = msg.fileName ?? loc.imagePreview;
              break;
            case 'file':
              preview = msg.fileName ?? loc.filePreview;
              break;
            default:
              preview = msg.content;
          }

          final time = '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

          return InkWell(
            onTap: () => onTap(messages.indexOf(msg)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isCurrent
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HighlightedText(
                      text: preview,
                      query: searchQuery,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface,
                      ),
                      highlightColor:
                          colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Search Navigation Bar ──────────────────────────────────

class _SearchNavBar extends StatelessWidget {
  final int matchCount;
  final int currentIdx;
  final AppLoc loc;
  final bool showList;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToggleList;
  final VoidCallback onClose;

  const _SearchNavBar({
    required this.matchCount,
    required this.currentIdx,
    required this.loc,
    required this.showList,
    required this.onPrev,
    required this.onNext,
    required this.onToggleList,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              matchCount > 0
                  ? loc.searchMatchCount(matchCount)
                  : loc.noMatchesInSession,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (matchCount > 0) ...[
              Text(
                '${currentIdx + 1}/$matchCount',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onPrev,
                icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                tooltip: loc.prevMatch,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                tooltip: loc.nextMatch,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onToggleList,
                icon: Icon(
                  showList
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 18,
                ),
                tooltip: showList ? 'Collapse' : 'Expand',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                    minWidth: 32, minHeight: 32),
              ),
            ],
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, size: 18,
                  color: Colors.grey.shade600),
              tooltip: loc.cancel,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Smart Time Divider (tap to toggle rough ↔ precise) ───

class _SmartTimeDivider extends StatefulWidget {
  final DateTime date;
  final AppLoc loc;
  const _SmartTimeDivider({required this.date, required this.loc});

  @override
  State<_SmartTimeDivider> createState() => _SmartTimeDividerState();
}

class _SmartTimeDividerState extends State<_SmartTimeDivider> {
  bool _precise = false;

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  bool _sameWeek(DateTime a, DateTime b) {
    final mon = b.subtract(Duration(days: b.weekday - 1));
    final sun = mon.add(const Duration(days: 6));
    return !a.isBefore(mon) && !a.isAfter(sun);
  }

  String _roughLabel() {
    final d = widget.date;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dateOnly).inDays;
    final t = _fmt(d);

    if (diff == 0) return t;
    if (diff == 1) return '${widget.loc.yesterday} $t';
    if (_sameWeek(dateOnly, today)) return '${widget.loc.weekdayName(d.weekday)} $t';
    if (d.year == today.year) {
      return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} $t';
    }
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} $t';
  }

  String _preciseLabel() {
    final d = widget.date;
    final now = DateTime.now();
    final t = _fmt(d);
    final w = widget.loc.weekdayName(d.weekday);
    final md = '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

    if (d.year == now.year) {
      return '$md $w $t';
    }
    return '${d.year}/$md $w $t';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _precise = !_precise),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _precise ? _preciseLabel() : _roughLabel(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
      ),
    );
  }
}

// ── Highlighted Text ───────────────────────────────────────

/// Renders [text] with all occurrences of [query] highlighted.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final int maxLines;
  final TextStyle style;
  final Color highlightColor;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.maxLines,
    required this.style,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines,
          overflow: TextOverflow.ellipsis);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (start < lowerText.length) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: TextStyle(
          backgroundColor: highlightColor,
          fontWeight: FontWeight.w600,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
