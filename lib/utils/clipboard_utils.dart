import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Copies an image file to the system clipboard on Windows using PowerShell.
Future<bool> copyImageToClipboard(String filePath) async {
  if (!Platform.isWindows) return false;
  try {
    final escapedPath = filePath.replaceAll('\\', '\\\\');
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; '
            '[Windows.Forms.Clipboard]::SetImage('
            '[System.Drawing.Image]::FromFile(\'$escapedPath\'))',
      ],
      runInShell: true,
    );
    return result.exitCode == 0;
  } catch (e) {
    debugPrint('[Clipboard] copyImageToClipboard failed: $e');
    return false;
  }
}

/// Checks whether the system clipboard currently contains an image.
Future<bool> clipboardHasImage() async {
  if (!Platform.isWindows) return false;
  try {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; '
            '[Windows.Forms.Clipboard]::ContainsImage()',
      ],
      runInShell: true,
    );
    return result.stdout.toString().trim().toLowerCase() == 'true';
  } catch (e) {
    debugPrint('[Clipboard] clipboardHasImage failed: $e');
    return false;
  }
}

/// Saves the image currently on the system clipboard to a PNG file inside
/// [directory].  Returns the saved file path, or `null` on failure.
Future<String?> saveClipboardImage(String directory) async {
  if (!Platform.isWindows) return null;
  try {
    final uuid = const Uuid().v4();
    final filePath = '$directory\\$uuid.png';
    final escapedPath = filePath.replaceAll('\\', '\\\\');

    // Ensure the target directory exists.
    await Directory(directory).create(recursive: true);

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; '
            '\$img = [Windows.Forms.Clipboard]::GetImage(); '
            'if (\$img -ne \$null) { '
            '\$img.Save(\'$escapedPath\', '
            '[System.Drawing.Imaging.ImageFormat]::Png) '
            '}',
      ],
      runInShell: true,
    );

    if (result.exitCode == 0 && await File(filePath).exists()) {
      return filePath;
    }
    return null;
  } catch (e) {
    debugPrint('[Clipboard] saveClipboardImage failed: $e');
    return null;
  }
}
