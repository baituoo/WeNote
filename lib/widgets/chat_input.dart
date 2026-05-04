import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/app_localizations.dart';
import '../utils/clipboard_utils.dart';

final chatInputControllerProvider =
    Provider.autoDispose<TextEditingController>(
  (ref) => TextEditingController(),
);

class ChatInput extends ConsumerStatefulWidget {
  final Function(String text) onSendText;
  final Function(String filePath, String fileName) onSendImage;
  final Function(String filePath, String fileName) onSendFile;
  final void Function(List<String> paths)? onPasteFiles;

  const ChatInput({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendFile,
    this.onPasteFiles,
  });

  @override
  ConsumerState<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends ConsumerState<ChatInput> {
  late final _focusNode = FocusNode(onKeyEvent: _onKeyEvent);

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final controller = ref.read(chatInputControllerProvider);
    final text = controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    controller.clear();
    _focusNode.requestFocus();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ctrl+V → paste (image or text)
      if (event.logicalKey == LogicalKeyboardKey.keyV &&
          HardwareKeyboard.instance.isControlPressed) {
        _handlePaste();
        return KeyEventResult.handled;
      }
      // Enter → send; Ctrl+Enter → newline
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        if (HardwareKeyboard.instance.isControlPressed) {
          _insertNewline();
        } else {
          _handleSend();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final controller = ref.read(chatInputControllerProvider);
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start;
    final end = sel.end;
    final newText = text.replaceRange(
        start < 0 ? text.length : start,
        end < 0 ? text.length : end,
        '\n');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  Future<void> _handlePaste() async {
    // Check for image in clipboard (Windows only)
    if (Platform.isWindows) {
      final hasImage = await clipboardHasImage();
      if (hasImage) {
        if (!mounted) return;
        final tempDir = await getTemporaryDirectory();
        final savedPath = await saveClipboardImage(tempDir.path);
        if (savedPath != null && mounted) {
          widget.onPasteFiles?.call([savedPath]);
        }
        return;
      }
    }

    // No image — paste text at cursor
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty && mounted) {
      final controller = ref.read(chatInputControllerProvider);
      final sel = controller.selection;
      final start = sel.start;
      final end = sel.end;
      if (start >= 0 && end <= controller.text.length) {
        final newText = controller.text.replaceRange(start, end, text);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start + text.length),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        widget.onSendImage(file.path!, file.name);
      }
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
      withReadStream: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        widget.onSendFile(file.path!, file.name);
      }
    }
  }

  Future<void> _screenshot() async {
    if (!Platform.isWindows) return;

    // Launch Windows Snipping Tool in region mode
    try {
      await Process.run('snippingtool.exe', ['/clip'], runInShell: true);
    } catch (_) {
      try {
        await Process.run('C:\\Windows\\System32\\SnippingTool.exe',
            ['/clip'], runInShell: true);
      } catch (_) {}
    }

    // Poll clipboard for the captured image
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      final hasImage = await clipboardHasImage();
      if (hasImage) {
        final tempDir = await getTemporaryDirectory();
        final savedPath = await saveClipboardImage(tempDir.path);
        if (savedPath != null && mounted) {
          widget.onPasteFiles?.call([savedPath]);
        }
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = ref.watch(chatInputControllerProvider);
    final loc = ref.loc;
    final fillColor =
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top buttons row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                      child: Row(
                        children: [
                          // Attach button
                          PopupMenuButton<String>(
                            offset: const Offset(0, -160),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'image',
                                child: ListTile(
                                  leading: const Icon(Icons.image_rounded,
                                      color: Colors.blue, size: 20),
                                  title: Text(loc.image,
                                      style: const TextStyle(fontSize: 14)),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              PopupMenuItem(
                                value: 'file',
                                child: ListTile(
                                  leading: const Icon(
                                      Icons.attach_file_rounded,
                                      color: Colors.orange,
                                      size: 20),
                                  title: Text(loc.file,
                                      style: const TextStyle(fontSize: 14)),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'image') {
                                _pickImage();
                              } else if (value == 'file') {
                                _pickFile();
                              }
                            },
                            child: Icon(
                              Icons.add_circle_outline_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Screenshot button
                          IconButton(
                            onPressed: _screenshot,
                            icon: Icon(
                              Icons.screenshot_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            tooltip: loc.screenshot,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    // Text input
                    TextField(
                      controller: controller,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 3,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: loc.typeMessage,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                            12, 0, 12, 10),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _handleSend,
                icon: const Icon(Icons.send_rounded, size: 20),
                color: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
