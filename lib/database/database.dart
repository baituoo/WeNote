import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Data model for a chat session.
class Session {
  final String id;
  final String name;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Session({
    required this.id,
    required this.name,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  Session copyWith({
    String? id,
    String? name,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      name: name ?? this.name,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'is_pinned': isPinned ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Session.fromMap(Map<String, Object?> map) => Session(
        id: map['id'] as String,
        name: map['name'] as String,
        isPinned: (map['is_pinned'] as int) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

/// Data model for a chat message.
class Message {
  final String id;
  final String sessionId;
  final String content;
  final String type; // 'text', 'image', 'file'
  final String? filePath;
  final String? fileName;
  final String? replyToId;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.type,
    this.filePath,
    this.fileName,
    this.replyToId,
    required this.createdAt,
  });

  bool get hasMedia => filePath != null && File(filePath!).existsSync();

  Map<String, Object?> toMap() => {
        'id': id,
        'session_id': sessionId,
        'content': content,
        'type': type,
        'file_path': filePath,
        'file_name': fileName,
        'reply_to_id': replyToId,
        'created_at': createdAt.toIso8601String(),
      };

  factory Message.fromMap(Map<String, Object?> map) => Message(
        id: map['id'] as String,
        sessionId: map['session_id'] as String,
        content: map['content'] as String,
        type: map['type'] as String,
        filePath: map['file_path'] as String?,
        fileName: map['file_name'] as String?,
        replyToId: map['reply_to_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// SQLite-backed database for WeNote using sqflite_common_ffi.
class AppDatabase {
  late final Database _db;
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  late String _basePath;
  String get basePath => _basePath;

  AppDatabase._();

  static Future<AppDatabase> create() async {
    debugPrint('[DB] Starting database initialization...');

    // Step 1: get app documents directory
    debugPrint('[DB] Step 1/5: Getting documents directory...');
    final dbFolder = await getApplicationDocumentsDirectory();
    debugPrint('[DB]   Documents dir: ${dbFolder.path}');

    final dir = Directory(p.join(dbFolder.path, 'notechat'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('[DB]   Created notechat directory');
    }

    final path = p.join(dir.path, 'notechat.db');
    debugPrint('[DB]   DB path: $path');

    // Step 2: initialize FFI
    debugPrint('[DB] Step 2/5: Initializing SQLite FFI...');
    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      debugPrint('[DB]   FFI initialized OK');
    } catch (e, stack) {
      debugPrint('[DB]   FFI init FAILED: $e');
      debugPrint('[DB]   Stack: $stack');
      rethrow;
    }

    // Step 3: open database
    debugPrint('[DB] Step 3/5: Opening database...');
    Database db;
    try {
      db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            debugPrint('[DB]   Creating tables (version $version)...');
            await _createTables(db);
            debugPrint('[DB]   Tables created');
          },
          onUpgrade: (db, oldVersion, newVersion) async {
            debugPrint(
                '[DB]   Upgrading from v$oldVersion to v$newVersion...');
            if (oldVersion < 2) {
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN file_path TEXT');
              await db.execute(
                  'ALTER TABLE messages ADD COLUMN file_name TEXT');
              debugPrint('[DB]   Added file_path/file_name columns');
            }
            if (oldVersion < 3) {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS settings (
                  key TEXT PRIMARY KEY,
                  value TEXT NOT NULL
                )
              ''');
              debugPrint('[DB]   Created settings table');
            }
          },
        ),
      );
      debugPrint('[DB]   Database opened OK');
    } catch (e, stack) {
      debugPrint('[DB]   Database open FAILED: $e');
      debugPrint('[DB]   Stack: $stack');
      rethrow;
    }

    // Step 4: create app instance
    debugPrint('[DB] Step 4/5: Creating AppDatabase instance...');
    final appDb = AppDatabase._();
    appDb._db = db;
    appDb._basePath = dir.path;

    // Step 5: ensure media directory
    debugPrint('[DB] Step 5/5: Ensuring media directory...');
    final mediaDir = Directory(p.join(appDb._basePath, 'media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
      debugPrint('[DB]   Created media directory');
    }

    debugPrint('[DB] Database initialization COMPLETE');
    return appDb;
  }

  static Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        content TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'text',
        file_path TEXT,
        file_name TEXT,
        reply_to_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Stream<void> get onChange => _changeController.stream;
  void _notify() => _changeController.add(null);

  Future<Directory> getMediaDirectory() async {
    String? customPath;
    try {
      customPath = await getSetting('media_path');
    } catch (e) {
      debugPrint('[DB] getMediaDirectory — getSetting failed: $e');
    }
    final dir = Directory(customPath ?? p.join(_basePath, 'media'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> close() async {
    await _changeController.close();
    await _db.close();
  }

  // ── Settings ──────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final maps = await _db.query('settings',
        where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  Future<void> removeSetting(String key) async {
    await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    _notify();
  }

  // ── Sessions ──────────────────────────────────────────

  Future<List<Session>> getSessions() async {
    final maps = await _db.query('sessions',
        orderBy: 'is_pinned DESC, updated_at DESC');
    return maps.map(Session.fromMap).toList();
  }

  Future<Session?> getSessionById(String id) async {
    final maps =
        await _db.query('sessions', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<void> addSession(Session session) async {
    await _db.insert('sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _notify();
  }

  Future<void> updateSession(Session session) async {
    await _db.update('sessions', session.toMap(),
        where: 'id = ?', whereArgs: [session.id]);
    _notify();
  }

  Future<void> deleteSession(String id) async {
    await _db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
    await _db.delete('sessions', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<List<Session>> searchSessions(String query) async {
    final maps = await _db.query('sessions',
        where: 'name LIKE ?',
        whereArgs: ['%$query%'],
        orderBy: 'is_pinned DESC, updated_at DESC');
    return maps.map(Session.fromMap).toList();
  }

  /// Search sessions by name or by message content.
  Future<List<Session>> searchSessionsWithMessages(String query) async {
    final maps = await _db.rawQuery('''
      SELECT DISTINCT s.* FROM sessions s
      LEFT JOIN messages m ON s.id = m.session_id
      WHERE s.name LIKE ? OR m.content LIKE ? OR m.file_name LIKE ?
      ORDER BY s.is_pinned DESC, s.updated_at DESC
    ''', ['%$query%', '%$query%', '%$query%']);
    return maps.map(Session.fromMap).toList();
  }

  /// Count messages matching [query] in a session.
  Future<int> countMatchingMessages(String sessionId, String query) async {
    final result = await _db.rawQuery(
      '''SELECT COUNT(*) as cnt FROM messages
         WHERE session_id = ? AND (content LIKE ? OR file_name LIKE ?)''',
      [sessionId, '%$query%', '%$query%'],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  /// Get the most recent message matching [query] in a session.
  Future<Message?> getLastMatchingMessage(
      String sessionId, String query) async {
    final maps = await _db.query('messages',
        where: 'session_id = ? AND (content LIKE ? OR file_name LIKE ?)',
        whereArgs: [sessionId, '%$query%', '%$query%'],
        orderBy: 'created_at DESC',
        limit: 1);
    if (maps.isEmpty) return null;
    return Message.fromMap(maps.first);
  }

  /// Get all messages matching [query] in a session, sorted by time.
  Future<List<Message>> searchMessagesInSession(
      String sessionId, String query) async {
    final maps = await _db.query('messages',
        where: 'session_id = ? AND (content LIKE ? OR file_name LIKE ?)',
        whereArgs: [sessionId, '%$query%', '%$query%'],
        orderBy: 'created_at ASC');
    return maps.map(Message.fromMap).toList();
  }

  // ── Messages ──────────────────────────────────────────

  Future<List<Message>> getMessages(String sessionId) async {
    final maps = await _db.query('messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at ASC');
    return maps.map(Message.fromMap).toList();
  }

  Future<void> addMessage(Message message) async {
    await _db.insert('messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    _notify();
  }

  Future<void> deleteMessage(String id) async {
    final maps =
        await _db.query('messages', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final msg = Message.fromMap(maps.first);
      if (msg.filePath != null) {
        final file = File(msg.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
    await _db.delete('messages', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<Message?> getLastMessage(String sessionId) async {
    final maps = await _db.query('messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at DESC',
        limit: 1);
    if (maps.isEmpty) return null;
    return Message.fromMap(maps.first);
  }

  Future<String> storeMediaFile(String sourcePath) async {
    final mediaDir = await getMediaDirectory();
    final ext = p.extension(sourcePath);
    final destName =
        '${DateTime.now().millisecondsSinceEpoch}_${p.basenameWithoutExtension(sourcePath)}$ext';
    final destPath = p.join(mediaDir.path, destName);
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
