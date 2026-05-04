import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';

class SessionTile extends StatelessWidget {
  final Session session;
  final Message? lastMessage;
  final String noMessagesText;
  final bool isActive;
  final VoidCallback onTap;
  final void Function(Offset position)? onContextMenu;
  final AppLoc loc;

  // Search-related
  final String searchQuery;
  final int matchCount;
  final Message? lastMatchingMessage;

  const SessionTile({
    super.key,
    required this.session,
    this.lastMessage,
    this.noMessagesText = 'No messages yet',
    required this.isActive,
    required this.onTap,
    this.onContextMenu,
    required this.loc,
    this.searchQuery = '',
    this.matchCount = 0,
    this.lastMatchingMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor =
        isActive ? colorScheme.primaryContainer : Colors.transparent;
    final now = DateTime.now();
    final updated = session.updatedAt;
    String timeStr;
    if (updated.year == now.year &&
        updated.month == now.month &&
        updated.day == now.day) {
      timeStr = DateFormat('HH:mm').format(updated);
    } else {
      timeStr = DateFormat('MM/dd').format(updated);
    }

    final isSearching = searchQuery.isNotEmpty && matchCount > 0;

    return Material(
      color: bgColor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onContextMenu != null
            ? () {
                final box = context.findRenderObject() as RenderBox;
                final center = box.size.center(Offset.zero);
                final globalPos = box.localToGlobal(center);
                onContextMenu!(globalPos);
              }
            : null,
        onSecondaryTapUp: onContextMenu != null
            ? (details) => onContextMenu!(details.globalPosition)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: isActive
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.2),
                    radius: 24,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: isActive
                          ? colorScheme.onPrimary
                          : colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  if (session.isPinned)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isActive
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isSearching)
                      _SearchPreview(
                        message: lastMatchingMessage!,
                        query: searchQuery,
                        matchCount: matchCount,
                        loc: loc,
                        colorScheme: colorScheme,
                      )
                    else
                      _NormalPreview(
                        lastMessage: lastMessage,
                        noMessagesText: noMessagesText,
                        loc: loc,
                        colorScheme: colorScheme,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Normal preview without search active.
class _NormalPreview extends StatelessWidget {
  final Message? lastMessage;
  final String noMessagesText;
  final AppLoc loc;
  final ColorScheme colorScheme;

  const _NormalPreview({
    required this.lastMessage,
    required this.noMessagesText,
    required this.loc,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final preview = lastMessage != null
        ? _previewText(lastMessage!)
        : noMessagesText;

    return Text(
      preview,
      style: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurface.withValues(alpha: 0.5),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _previewText(Message msg) {
    switch (msg.type) {
      case 'image':
        return loc.imagePreview;
      case 'file':
        return loc.filePreview;
      default:
        return msg.content;
    }
  }
}

/// Search preview: highlights matching text and shows match count.
class _SearchPreview extends StatelessWidget {
  final Message message;
  final String query;
  final int matchCount;
  final AppLoc loc;
  final ColorScheme colorScheme;

  const _SearchPreview({
    required this.message,
    required this.query,
    required this.matchCount,
    required this.loc,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    // For media matches, show the file name so the search term
    // is visible in the preview (e.g. searching "screen" matches
    // "screenshot.png").
    final String text;
    switch (message.type) {
      case 'image':
        text = message.fileName ?? loc.imagePreview;
        break;
      case 'file':
        text = message.fileName ?? loc.filePreview;
        break;
      default:
        text = message.content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HighlightedText(
          text: text,
          query: query,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          highlightColor: colorScheme.primary.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 2),
        Text(
          loc.searchMatchCount(matchCount),
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Renders text with [query] highlighted via background color.
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
