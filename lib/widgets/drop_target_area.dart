import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Wraps a child widget with native desktop drag-and-drop support.
///
/// When files are dropped, [onFilesDropped] is called with the list of
/// file paths.
class DropTargetArea extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final void Function(List<String> paths) onFilesDropped;

  const DropTargetArea({
    super.key,
    required this.child,
    this.enabled = true,
    required this.onFilesDropped,
  });

  @override
  State<DropTargetArea> createState() => _DropTargetAreaState();
}

class _DropTargetAreaState extends State<DropTargetArea> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Stack(
      children: [
        DropTarget(
          onDragEntered: (_) {
            debugPrint('[DropTarget] Drag entered');
            setState(() => _dragging = true);
          },
          onDragExited: (_) {
            debugPrint('[DropTarget] Drag exited');
            setState(() => _dragging = false);
          },
          onDragDone: (detail) {
            debugPrint(
                '[DropTarget] Drag done — ${detail.files.length} files');
            setState(() => _dragging = false);

            final paths = <String>[];
            for (final f in detail.files) {
              debugPrint('[DropTarget]   file: ${f.name} path: ${f.path}');
              if (f.path.isNotEmpty) {
                paths.add(f.path);
              }
            }
            if (paths.isNotEmpty) {
              widget.onFilesDropped(paths);
            }
          },
          child: widget.child,
        ),
        // Drag-overlay: subtle border hint
        if (_dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.08),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.enabled ? 'Drop to send' : '',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dialog shown after dropping a file onto the chat area.
class SendConfirmDialog extends StatefulWidget {
  final List<String> filePaths;
  final AppLoc loc;

  const SendConfirmDialog({
    super.key,
    required this.filePaths,
    required this.loc,
  });

  @override
  State<SendConfirmDialog> createState() => _SendConfirmDialogState();
}

class _SendConfirmDialogState extends State<SendConfirmDialog> {
  final _textController = TextEditingController();
  late final _focusNode = FocusNode(onKeyEvent: _onKeyEvent);

  bool get _allImages => widget.filePaths.every(_isImage);
  bool get _allFiles => widget.filePaths.every((p) => !_isImage(p));

  String get _typeLabel {
    if (_allImages) return widget.loc.image;
    if (_allFiles) return widget.loc.file;
    return widget.loc.file;
  }

  static bool _isImage(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp', 'tiff'].contains(ext);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      if (HardwareKeyboard.instance.isControlPressed) {
        _insertNewline();
      } else {
        Navigator.of(context).pop(_textController.text);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final text = _textController.text;
    final sel = _textController.selection;
    final start = sel.start;
    final end = sel.end;
    final newText = text.replaceRange(
        start < 0 ? text.length : start,
        end < 0 ? text.length : end,
        '\n');
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        '${widget.loc.create} $_typeLabel',
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.filePaths.length == 1) ...[
              if (_allImages)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.filePaths.first),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _buildFileCard(widget.filePaths.first),
                  ),
                )
              else
                _buildFileCard(widget.filePaths.first),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.filePaths.length} $_typeLabel',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...widget.filePaths.take(5).map(
                          (p) => Text(
                            p.split(Platform.pathSeparator).last,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    if (widget.filePaths.length > 5)
                      Text(
                        '... and ${widget.filePaths.length - 5} more',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: widget.loc.typeMessage,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(widget.loc.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_textController.text);
          },
          child: Text(widget.loc.create),
        ),
      ],
    );
  }

  Widget _buildFileCard(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final file = File(path);
    int? size;
    try {
      size = file.lengthSync();
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_rounded, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (size != null)
                  Text(widget.loc.fileSize(size),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
