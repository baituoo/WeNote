import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';
import '../utils/clipboard_utils.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final AppLoc loc;
  final String searchQuery;
  final bool isSearchMatch;
  final void Function(String filePath)? onOpenFile;
  final void Function(String imagePath)? onTapImage;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.loc,
    this.isMe = true,
    this.searchQuery = '',
    this.isSearchMatch = false,
    this.onOpenFile,
    this.onTapImage,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isMe
        ? colorScheme.primaryContainer
        : (isDark ? Colors.grey.shade800 : Colors.grey.shade100);
    final fgColor =
        isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
              radius: 16,
              child:
                  Icon(Icons.person, size: 18, color: colorScheme.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.5,
              ),
              decoration: BoxDecoration(
                color: isSearchMatch
                    ? bgColor.withValues(alpha: 0.85)
                    : bgColor,
                borderRadius: radius,
                border: isSearchMatch
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      )
                    : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bubbleWidth = constraints.maxWidth;
                  return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.replyToId != null)
                    _ReplyBanner(message: message),
                  if (message.type == 'image' && message.filePath != null)
                    _ImageContent(
                      filePath: message.filePath!,
                      width: bubbleWidth,
                      loc: loc,
                      onDelete: onDelete,
                      onTap: onTapImage != null
                          ? () => onTapImage!(message.filePath!)
                          : null,
                    ),
                  if (message.type == 'file' && message.filePath != null)
                    _FileContent(
                      message: message,
                      loc: loc,
                      onDelete: onDelete,
                      onOpenFile: onOpenFile,
                    ),
                  if (message.content.isNotEmpty)
                    Padding(
                      padding: _contentPadding(message),
                      child: _TextContent(
                        text: message.content,
                        textColor: fgColor,
                        loc: loc,
                        searchQuery: searchQuery,
                        onDelete: onDelete,
                      ),
                    ),
                  // Time removed from bubble — shown in dividers above messages instead.
                ],
              );
            },
          ),
        ),
      ),
      if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 16,
              child:
                  const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  EdgeInsets _contentPadding(Message message) {
    final hasMedia = message.type == 'image' || message.type == 'file';
    if (hasMedia) {
      return const EdgeInsets.fromLTRB(14, 8, 14, 4);
    }
    return const EdgeInsets.fromLTRB(14, 10, 14, 4);
  }

}

class _ReplyBanner extends StatelessWidget {
  final Message message;
  const _ReplyBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final appLoc = AppLoc('en');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.fromLTRB(6, 6, 6, 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: Colors.black38, width: 3),
        ),
      ),
      child: Text(
        appLoc.repliedMessage,
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  final String filePath;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final AppLoc loc;

  const _ImageContent({
    required this.filePath,
    required this.width,
    required this.loc,
    this.onTap,
    this.onDelete,
  });

  void _showContextMenu(BuildContext context, TapUpDetails details) async {
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18),
              const SizedBox(width: 8),
              Text(loc.copyImage),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Text(loc.deleteMessage,
                  style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    );
    if (!context.mounted) return;

    if (value == 'copy') {
      final ok = await copyImageToClipboard(filePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? loc.copied : loc.unknownFile,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 80,
            margin: const EdgeInsets.only(bottom: 80),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        );
      }
    } else if (value == 'delete') {
      _confirmDelete(context);
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteMessage),
        content: Text(loc.deleteMessageConfirm('')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              onDelete?.call();
            },
            child: Text(loc.delete, style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Icon(Icons.broken_image_rounded, size: 48),
      );
    }

    return GestureDetector(
      onTap: onTap,
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Image.file(
          file,
          fit: BoxFit.fitWidth,
          width: width,
          errorBuilder: (_, _, _) => const Padding(
            padding: EdgeInsets.all(24),
            child: Icon(Icons.broken_image_rounded, size: 48),
          ),
        ),
      ),
    );
  }
}

class _FileContent extends StatelessWidget {
  final Message message;
  final void Function(String filePath)? onOpenFile;
  final VoidCallback? onDelete;
  final AppLoc loc;

  const _FileContent({
    required this.message,
    required this.loc,
    this.onOpenFile,
    this.onDelete,
  });

  IconData _fileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_rounded;
      case 'txt':
      case 'md':
        return Icons.article_rounded;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file_rounded;
      case 'mp4':
      case 'avi':
      case 'mkv':
        return Icons.video_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = message.fileName ?? message.content;
    int? fileSize;
    if (message.filePath != null) {
      final file = File(message.filePath!);
      if (file.existsSync()) {
        fileSize = file.lengthSync();
      }
    }

    return GestureDetector(
      onSecondaryTapUp: (details) async {
        final value = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy,
            details.globalPosition.dx + 1,
            details.globalPosition.dy + 1,
          ),
          items: [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Text(loc.deleteMessage,
                      style: TextStyle(color: Colors.red.shade400)),
                ],
              ),
            ),
          ],
        );
        if (value == 'delete' && context.mounted) {
          showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(loc.deleteMessage),
              content: Text(loc.deleteMessageConfirm('')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(loc.cancel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx, true);
                    onDelete?.call();
                  },
                  child: Text(loc.delete,
                      style: TextStyle(color: Colors.red.shade400)),
                ),
              ],
            ),
          );
        }
      },
      child: InkWell(
        onTap: onOpenFile != null && message.filePath != null
            ? () => onOpenFile!(message.filePath!)
            : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(_fileIcon(fileName), size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (fileSize != null)
                      Text(
                        loc.fileSize(fileSize),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextContent extends StatefulWidget {
  final String text;
  final Color textColor;
  final AppLoc loc;
  final String searchQuery;
  final VoidCallback? onDelete;

  const _TextContent({
    required this.text,
    required this.textColor,
    required this.loc,
    this.searchQuery = '',
    this.onDelete,
  });

  @override
  State<_TextContent> createState() => _TextContentState();
}

class _TextContentState extends State<_TextContent> {
  bool _showing = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _showPopup(Offset globalPos) async {
    if (_showing) return;
    _showing = true;

    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx + 1,
        globalPos.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy, size: 18),
              const SizedBox(width: 8),
              Text(widget.loc.copyMessage),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: Colors.red.shade400),
              const SizedBox(width: 8),
              Text(widget.loc.deleteMessage,
                  style: TextStyle(color: Colors.red.shade400)),
            ],
          ),
        ),
      ],
    );

    _showing = false;
    if (!mounted) return;

    // Re-focus to restore selection highlight (best-effort, deferred)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _focusNode.requestFocus();
        } catch (_) {}
      }
    });

    if (value == 'copy') {
      await Clipboard.setData(ClipboardData(text: widget.text));
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.loc.copied,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              duration: const Duration(milliseconds: 800),
              behavior: SnackBarBehavior.floating,
              width: 80,
              margin: const EdgeInsets.only(bottom: 80),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          );
        } catch (_) {}
      }
    } else if (value == 'delete') {
      _confirmDelete();
    }
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.loc.deleteMessage),
        content: Text(widget.loc.deleteMessageConfirm('')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(widget.loc.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              widget.onDelete?.call();
            },
            child: Text(widget.loc.delete,
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }

  TextSpan _buildTextSpan() {
    final baseStyle = TextStyle(
      fontSize: 15,
      color: widget.textColor,
      height: 1.3,
    );

    final q = widget.searchQuery;
    if (q.isEmpty) {
      return TextSpan(text: widget.text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final lowerText = widget.text.toLowerCase();
    final lowerQuery = q.toLowerCase();
    int start = 0;

    while (start < lowerText.length) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: widget.text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: widget.text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: widget.text.substring(idx, idx + q.length),
        style: TextStyle(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          fontWeight: FontWeight.w600,
          color: widget.textColor,
        ),
      ));
      start = idx + q.length;
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          _showPopup(event.position);
        }
      },
      child: SelectableText.rich(
        _buildTextSpan(),
        focusNode: _focusNode,
        strutStyle: StrutStyle.disabled,
        selectionHeightStyle: ui.BoxHeightStyle.tight,
        selectionWidthStyle: ui.BoxWidthStyle.tight,
        contextMenuBuilder: (ctx, editableTextState) =>
            const SizedBox.shrink(),
      ),
    );
  }
}
