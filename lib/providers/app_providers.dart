import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../l10n/app_localizations.dart';

// ── Database ──────────────────────────────────────────────

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  debugPrint('[Provider] Creating AppDatabase...');
  try {
    final db = await AppDatabase.create();
    debugPrint('[Provider] AppDatabase created OK');
    ref.onDispose(() {
      debugPrint('[Provider] Closing AppDatabase...');
      db.close();
    });
    return db;
  } catch (e, stack) {
    debugPrint('[Provider] AppDatabase creation FAILED: $e');
    debugPrint('[Provider] Stack: $stack');
    rethrow;
  }
});

// ── Settings ──────────────────────────────────────────────

final settingsLoadedProvider = StateProvider<bool>((ref) => false);

/// Whether a fatal init error occurred (shown on splash screen).
final initErrorProvider = StateProvider<String?>((ref) => null);

/// Load persisted settings on app start.
/// This always sets [settingsLoadedProvider] to true so the UI unblocks,
/// even if parts of the init chain fail.
Future<void> loadSettings(WidgetRef ref) async {
  debugPrint('[Init] loadSettings: starting...');

  // Step 1: get database
  AppDatabase db;
  try {
    debugPrint('[Init] loadSettings: waiting for database...');
    db = await ref.read(databaseProvider.future);
    debugPrint('[Init] loadSettings: database ready');
  } catch (e, stack) {
    debugPrint('[Init] loadSettings: database FAILED — $e');
    debugPrint('[Init] Stack: $stack');
    ref.read(initErrorProvider.notifier).state = 'Database init failed: $e';
    ref.read(settingsLoadedProvider.notifier).state = true;
    return;
  }

  // Step 2: load language
  try {
    final lang = await db.getSetting('language');
    if (lang != null && (lang == 'zh' || lang == 'en')) {
      ref.read(localeProvider.notifier).state = lang;
      debugPrint('[Init] loadSettings: language = $lang');
    } else {
      debugPrint('[Init] loadSettings: no language setting, using default');
    }
  } catch (e) {
    debugPrint('[Init] loadSettings: language load failed — $e');
  }

  // Step 3: load theme color
  try {
    final color = await db.getSetting('theme_color');
    if (color != null) {
      ref.read(themeColorProvider.notifier).state = Color(int.parse(color));
      debugPrint('[Init] loadSettings: theme_color = $color');
    } else {
      debugPrint('[Init] loadSettings: no theme_color, using default');
    }
  } catch (e) {
    debugPrint('[Init] loadSettings: theme_color load failed — $e');
  }

  debugPrint('[Init] loadSettings: COMPLETE');
  ref.read(settingsLoadedProvider.notifier).state = true;
}

Future<void> saveSetting(WidgetRef ref, String key, String value) async {
  try {
    final db = await ref.read(databaseProvider.future);
    await db.setSetting(key, value);
  } catch (e) {
    debugPrint('[Provider] saveSetting($key) failed: $e');
  }
}

// ── Theme Color ───────────────────────────────────────────

final themeColorProvider = StateProvider<Color>(
    (ref) => const Color(0xFF07C160)); // WeChat green default

// ── Sessions ──────────────────────────────────────────────

class SessionState {
  final List<Session> sessions;
  final bool loading;

  const SessionState({this.sessions = const [], this.loading = false});
}

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref _ref;

  SessionNotifier(this._ref) : super(const SessionState(loading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final db = await _ref.read(databaseProvider.future);
      final sessions = await db.getSessions();
      state = SessionState(sessions: sessions);
    } catch (e) {
      debugPrint('[SessionNotifier] _load failed: $e');
      state = const SessionState();
    }
  }

  Future<void> addSession(Session session) async {
    final db = await _ref.read(databaseProvider.future);
    await db.addSession(session);
    await _load();
  }

  Future<void> updateSession(Session session) async {
    final db = await _ref.read(databaseProvider.future);
    await db.updateSession(session);
    await _load();
  }

  Future<void> deleteSession(String id) async {
    final db = await _ref.read(databaseProvider.future);
    await db.deleteSession(id);
    await _load();
  }

  void refresh() => _load();
}

final sessionNotifierProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier(ref);
});

final sessionsProvider = Provider<List<Session>>((ref) {
  return ref.watch(sessionNotifierProvider).sessions;
});

final currentSessionIdProvider = StateProvider<String?>((ref) => null);

final currentSessionProvider = Provider<Session?>((ref) {
  final sessionId = ref.watch(currentSessionIdProvider);
  if (sessionId == null) return null;
  final sessions = ref.watch(sessionsProvider);
  try {
    return sessions.firstWhere((s) => s.id == sessionId);
  } catch (_) {
    return null;
  }
});

// ── Messages ──────────────────────────────────────────────

class MessageState {
  final List<Message> messages;
  final bool loading;

  const MessageState({this.messages = const [], this.loading = false});
}

class MessageNotifier extends StateNotifier<MessageState> {
  final Ref _ref;

  MessageNotifier(this._ref) : super(const MessageState(loading: true));

  Future<void> loadMessages(String sessionId) async {
    state = const MessageState(loading: true);
    try {
      final db = await _ref.read(databaseProvider.future);
      final messages = await db.getMessages(sessionId);
      state = MessageState(messages: messages);
    } catch (e) {
      debugPrint('[MessageNotifier] loadMessages failed: $e');
      state = const MessageState();
    }
  }

  Future<void> addMessage(Message message) async {
    final db = await _ref.read(databaseProvider.future);
    await db.addMessage(message);

    final session = await db.getSessionById(message.sessionId);
    if (session != null) {
      await db.updateSession(session.copyWith(updatedAt: DateTime.now()));
    }

    final messages = await db.getMessages(message.sessionId);
    state = MessageState(messages: messages);

    _ref.read(sessionNotifierProvider.notifier).refresh();
    _ref.invalidate(lastMessageProvider(message.sessionId));
    _ref.invalidate(matchCountProvider(message.sessionId));
    _ref.invalidate(lastMatchingMessageProvider(message.sessionId));
    _ref.invalidate(matchingMessagesProvider(message.sessionId));
  }

  Future<void> addMediaMessage({
    required String sessionId,
    required String type,
    required String filePath,
    required String fileName,
    String content = '',
  }) async {
    final db = await _ref.read(databaseProvider.future);
    final uuid = _ref.read(uuidProvider);
    final now = DateTime.now();

    final storedPath = await db.storeMediaFile(filePath);

    final message = Message(
      id: uuid.v4(),
      sessionId: sessionId,
      content: content,
      type: type,
      filePath: storedPath,
      fileName: fileName,
      createdAt: now,
    );

    await addMessage(message);
  }

  Future<void> deleteMessage(Message message) async {
    final db = await _ref.read(databaseProvider.future);
    await db.deleteMessage(message.id);
    // Reload messages for this session
    final messages = await db.getMessages(message.sessionId);
    state = MessageState(messages: messages);
    // Refresh session list (last message preview)
    _ref.read(sessionNotifierProvider.notifier).refresh();
    _ref.invalidate(lastMessageProvider(message.sessionId));
    _ref.invalidate(matchCountProvider(message.sessionId));
    _ref.invalidate(lastMatchingMessageProvider(message.sessionId));
    _ref.invalidate(matchingMessagesProvider(message.sessionId));
  }

  void clear() {
    state = const MessageState();
  }
}

final messageNotifierProvider =
    StateNotifierProvider<MessageNotifier, MessageState>((ref) {
  return MessageNotifier(ref);
});

final messagesProvider = Provider<List<Message>>((ref) {
  return ref.watch(messageNotifierProvider).messages;
});

// ── Last message ──────────────────────────────────────────

final lastMessageProvider =
    FutureProvider.family<Message?, String>((ref, sessionId) async {
  try {
    final db = await ref.watch(databaseProvider.future);
    return db.getLastMessage(sessionId);
  } catch (e) {
    debugPrint('[lastMessageProvider] failed: $e');
    return null;
  }
});

// ── Search ─────────────────────────────────────────────────

/// Shared search query — session list writes, chat view reads.
final activeSearchQueryProvider = StateProvider<String>((ref) => '');

final searchedSessionsProvider =
    FutureProvider.family<List<Session>, String>((ref, query) async {
  if (query.isEmpty) return [];
  try {
    final db = await ref.watch(databaseProvider.future);
    return db.searchSessionsWithMessages(query);
  } catch (e) {
    debugPrint('[searchedSessionsProvider] failed: $e');
    return [];
  }
});

final matchCountProvider =
    FutureProvider.family<int, String>((ref, sessionId) async {
  final query = ref.watch(activeSearchQueryProvider);
  if (query.isEmpty) return 0;
  try {
    final db = await ref.watch(databaseProvider.future);
    return db.countMatchingMessages(sessionId, query);
  } catch (e) {
    debugPrint('[matchCountProvider] failed: $e');
    return 0;
  }
});

final lastMatchingMessageProvider =
    FutureProvider.family<Message?, String>((ref, sessionId) async {
  final query = ref.watch(activeSearchQueryProvider);
  if (query.isEmpty) return null;
  try {
    final db = await ref.watch(databaseProvider.future);
    return db.getLastMatchingMessage(sessionId, query);
  } catch (e) {
    debugPrint('[lastMatchingMessageProvider] failed: $e');
    return null;
  }
});

final matchingMessagesProvider =
    FutureProvider.family<List<Message>, String>((ref, sessionId) async {
  final query = ref.watch(activeSearchQueryProvider);
  if (query.isEmpty) return [];
  try {
    final db = await ref.watch(databaseProvider.future);
    return db.searchMessagesInSession(sessionId, query);
  } catch (e) {
    debugPrint('[matchingMessagesProvider] failed: $e');
    return [];
  }
});

// ── Theme Mode ────────────────────────────────────────────

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// ── Uuid ──────────────────────────────────────────────────

final uuidProvider = Provider<Uuid>((ref) => const Uuid());
