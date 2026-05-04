import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.loc;
    final colorScheme = Theme.of(context).colorScheme;
    final themeColor = ref.watch(themeColorProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          // ── Language ─────────────────────────────
          _SectionHeader(title: loc.language),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(loc.language),
            subtitle: Text(currentLocale == 'zh' ? '中文' : 'English'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'zh', label: Text('中文')),
              ],
              selected: {currentLocale},
              onSelectionChanged: (value) async {
                ref.read(localeProvider.notifier).state = value.first;
                await saveSetting(ref, 'language', value.first);
              },
            ),
          ),
          const Divider(),

          // ── Theme Color ─────────────────────────
          _SectionHeader(title: loc.themeColor),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: themeColor,
              radius: 16,
            ),
            title: Text(loc.themeColor),
            subtitle: Text(
              '#${themeColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map((color) {
                final isSelected = color.toARGB32() == themeColor.toARGB32();
                return GestureDetector(
                  onTap: () async {
                    ref.read(themeColorProvider.notifier).state = color;
                    await saveSetting(
                        ref, 'theme_color', color.toARGB32().toString());
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: colorScheme.onSurface, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final color = await showDialog<Color>(
                      context: context,
                      builder: (ctx) => _ColorPickerDialog(
                          currentColor: themeColor),
                    );
                    if (color != null) {
                      ref.read(themeColorProvider.notifier).state = color;
                      await saveSetting(
                          ref, 'theme_color', color.toARGB32().toString());
                    }
                  },
                  icon: const Icon(Icons.colorize_rounded, size: 18),
                  label: Text(loc.pickColor),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    const defaultColor = Color(0xFF07C160);
                    ref.read(themeColorProvider.notifier).state = defaultColor;
                    await saveSetting(
                        ref, 'theme_color', defaultColor.toARGB32().toString());
                  },
                  child: Text(loc.resetColor),
                ),
              ],
            ),
          ),
          const Divider(),

          // ── Theme Mode ──────────────────────────
          _SectionHeader(title: loc.toggleTheme),
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
            ),
            title: Text(themeMode == ThemeMode.dark ? 'Dark' : 'Light'),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (isDark) {
                ref.read(themeModeProvider.notifier).state =
                    isDark ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ),
          const Divider(),

          // ── Storage Path ────────────────────────
          _SectionHeader(title: loc.storagePath),
          ListTile(
            leading: const Icon(Icons.folder_rounded),
            title: Text(loc.storagePath),
            subtitle: FutureBuilder<String>(
              future: _getMediaPath(ref),
              builder: (context, snapshot) {
                return Text(
                  snapshot.data ?? loc.currentPath,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: OutlinedButton.icon(
              onPressed: () => _changeStoragePath(context, ref),
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(loc.changePath),
            ),
          ),
          const Divider(),

          // ── About ───────────────────────────────
          _SectionHeader(title: loc.about),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              loc.aboutText,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getMediaPath(WidgetRef ref) async {
    final db = await ref.read(databaseProvider.future);
    final dir = await db.getMediaDirectory();
    return dir.path;
  }

  Future<void> _changeStoragePath(
      BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select media storage folder',
    );
    if (result != null) {
      await saveSetting(ref, 'media_path', result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result)),
        );
      }
    }
  }

  static const _presetColors = [
    Color(0xFF07C160), // WeChat green
    Color(0xFF1976D2), // Blue
    Color(0xFFE53935), // Red
    Color(0xFF8E24AA), // Purple
    Color(0xFFFF6F00), // Orange
    Color(0xFF00897B), // Teal
    Color(0xFF546E7A), // Blue grey
    Color(0xFFFF8C00), // Dark orange
    Color(0xFF3F51B5), // Indigo
    Color(0xFFC0CA33), // Lime
  ];
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final Color currentColor;

  const _ColorPickerDialog({required this.currentColor});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late double _red, _green, _blue;

  @override
  void initState() {
    super.initState();
    _red = widget.currentColor.r.toDouble();
    _green = widget.currentColor.g.toDouble();
    _blue = widget.currentColor.b.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final preview = Color.fromARGB(
        255, _red.toInt(), _green.toInt(), _blue.toInt());

    return AlertDialog(
      title: const Text('Pick a color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: preview,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: preview.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSlider('R', _red, Colors.red, (v) => setState(() => _red = v)),
          _buildSlider(
              'G', _green, Colors.green, (v) => setState(() => _green = v)),
          _buildSlider(
              'B', _blue, Colors.blue, (v) => setState(() => _blue = v)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(preview),
          child: const Text('Select'),
        ),
      ],
    );
  }

  Widget _buildSlider(
      String label, double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color)),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            value.round().toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}
