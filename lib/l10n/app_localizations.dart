import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported locale keys.
const supportedLocales = ['en', 'zh'];

/// Central place for all localizable UI strings.
class AppLoc {
  final String locale;

  const AppLoc(this.locale);

  bool get isZh => locale == 'zh';

  // ── App ────────────────────────────────────────────────
  String get appTitle => isZh ? '微记' : 'WeNote';
  String get toggleTheme => isZh ? '切换主题' : 'Toggle theme';

  // ── Session List ───────────────────────────────────────
  String get searchSessions => isZh ? '搜索会话...' : 'Search sessions...';
  String get noConversations => isZh ? '暂无会话' : 'No conversations yet';
  String get clickToStart => isZh ? '点击 + 新建会话' : 'Click + to start a new session';
  String get newSession => isZh ? '新建会话' : 'New Session';
  String get sessionName => isZh ? '会话名称' : 'Session name';
  String get noMatching => isZh ? '无匹配会话' : 'No matching sessions';
  String get noMessages => isZh ? '暂无消息' : 'No messages yet';
  String get imagePreview => isZh ? '[图片]' : '[Image]';
  String get filePreview => isZh ? '[文件]' : '[File]';
  String searchMatchCount(int n) =>
      isZh ? '共有$n条相关的聊天记录' : '$n matching messages';
  String get noMatchesInSession =>
      isZh ? '无匹配消息' : 'No matching messages';
  String get nextMatch => isZh ? '下一个' : 'Next';
  String get prevMatch => isZh ? '上一个' : 'Previous';
  String get renameSession => isZh ? '重命名会话' : 'Rename Session';
  String get deleteSession => isZh ? '删除会话' : 'Delete Session';
  String deleteConfirm(String name) =>
      isZh ? '确定要删除"$name"吗？此操作不可撤销。' : 'Are you sure you want to delete "$name"? This cannot be undone.';
  String get pin => isZh ? '置顶' : 'Pin';
  String get unpin => isZh ? '取消置顶' : 'Unpin';
  String get rename => isZh ? '重命名' : 'Rename';
  String get delete => isZh ? '删除' : 'Delete';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get create => isZh ? '创建' : 'Create';
  String get save => isZh ? '保存' : 'Save';

  // ── Chat View ──────────────────────────────────────────
  String get selectConversation => isZh ? '选择一个会话' : 'Select a conversation';
  String get orCreateNew => isZh ? '或创建一个新会话开始记录' : 'or create a new one to get started';
  String get sendFirstMessage => isZh ? '发送第一条消息吧！' : 'Send your first message!';
  String get typeMessage => isZh ? '输入消息...' : 'Type a message...';
  String get today => isZh ? '今天' : 'Today';
  String get yesterday => isZh ? '昨天' : 'Yesterday';
  String get copyMessage => isZh ? '复制' : 'Copy';
  String get copyImage => isZh ? '复制图片' : 'Copy image';
  String get imageCopied => isZh ? '图片已复制' : 'Image copied';
  String get copied => isZh ? '已复制' : 'Copied';
  String get deleteMessage => isZh ? '删除消息' : 'Delete message';
  String deleteMessageConfirm(String name) =>
      isZh ? '确定要删除这条消息吗？' : 'Are you sure you want to delete this message?';

  /// Returns localized weekday name (Monday = 1 … Sunday = 7).
  String weekdayName(int weekday) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const zh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return isZh ? zh[weekday - 1] : en[weekday - 1];
  }
  String get repliedMessage => isZh ? '引用的消息' : 'Replied message';
  String get image => isZh ? '图片' : 'Image';
  String get screenshot => isZh ? '截图' : 'Screenshot';
  String get file => isZh ? '文件' : 'File';
  String get openFile => isZh ? '打开文件' : 'Open file';
  String get saveImage => isZh ? '保存图片' : 'Save image';

  // ── Settings ───────────────────────────────────────────
  String get settings => isZh ? '设置' : 'Settings';
  String get language => isZh ? '语言' : 'Language';
  String get themeColor => isZh ? '主题颜色' : 'Theme Color';
  String get storagePath => isZh ? '媒体文件保存位置' : 'Media Storage Path';
  String get currentPath => isZh ? '当前路径' : 'Current path';
  String get changePath => isZh ? '更改路径' : 'Change path';
  String get pickColor => isZh ? '选择颜色' : 'Pick a color';
  String get resetColor => isZh ? '恢复默认颜色' : 'Reset to default';
  String get about => isZh ? '关于' : 'About';
  String get aboutText =>
      isZh ? '微记 - 一款类微信聊天界面的桌面笔记应用\n版本 1.0.0' : 'WeNote - A WeChat-style desktop note-taking app\nVersion 1.0.0';

  // ── File Attachment ────────────────────────────────────
  String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get unknownFile => isZh ? '未知文件' : 'Unknown file';
}

// ── Provider ─────────────────────────────────────────────

final localeProvider = StateProvider<String>((ref) => 'zh');

final appLocProvider = Provider<AppLoc>((ref) {
  final locale = ref.watch(localeProvider);
  return AppLoc(locale);
});

/// Extension to easily access AppLoc from BuildContext via Riverpod.
extension AppLocX on WidgetRef {
  AppLoc get loc => watch(appLocProvider);
}
