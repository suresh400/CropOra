import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'agroguide_app.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
           await db.execute('CREATE TABLE IF NOT EXISTS chat(id INTEGER PRIMARY KEY AUTOINCREMENT, message TEXT, is_user INTEGER, timestamp TEXT)');
        }
        if (oldVersion < 3) {
           await db.execute('''
             CREATE TABLE IF NOT EXISTS reminders(
               id INTEGER PRIMARY KEY AUTOINCREMENT,
               crop_type TEXT,
               fertilizer_name TEXT,
               cultivation_days INTEGER,
               timestamp TEXT
             )
           ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ai_cache(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              question TEXT UNIQUE,
              answer TEXT,
              source TEXT,
              timestamp TEXT,
              used_count INTEGER DEFAULT 1
            )
          ''');
        }
      }
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        input_data TEXT,
        result_data TEXT,
        timestamp TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS chat(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT,
        is_user INTEGER,
        timestamp TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        crop_type TEXT,
        fertilizer_name TEXT,
        cultivation_days INTEGER,
        timestamp TEXT
      )
    ''');

    // AI Q&A cache for instant repeated-question responses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_cache(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT UNIQUE,
        answer TEXT,
        source TEXT,
        timestamp TEXT,
        used_count INTEGER DEFAULT 1
      )
    ''');
  }

  // --- History --- //
  Future<int> insertHistory(String type, Map<String, dynamic> input, Map<String, dynamic> result) async {
    try {
      final db = await database;
      return await db.insert(
        'history',
        {
          'type': type,
          'input_data': jsonEncode(input),
          'result_data': jsonEncode(result),
          'timestamp': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("SQLite insertHistory error: \$e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getHistory(String type) async {
    try {
      final db = await database;
      return await db.query(
        'history',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'timestamp DESC',
      );
    } catch (e) {
      debugPrint("SQLite getHistory error: \$e");
      return [];
    }
  }

  // --- Chat --- //
  Future<int> insertChatMessage(String message, bool isUser) async {
    try {
      final db = await database;
      return await db.insert(
        'chat',
        {
          'message': message,
          'is_user': isUser ? 1 : 0,
          'timestamp': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("SQLite insertChatMessage error: \$e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    try {
      final db = await database;
      return await db.query(
        'chat',
        orderBy: 'timestamp ASC',
      );
    } catch (e) {
      debugPrint("SQLite getChatHistory error: \$e");
      return [];
    }
  }

  // --- Reminders --- //
  Future<int> insertReminder(String crop, String fertilizer, int days) async {
    try {
      final db = await database;
      return await db.insert(
        'reminders',
        {
          'crop_type': crop,
          'fertilizer_name': fertilizer,
          'cultivation_days': days,
          'timestamp': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("SQLite insertReminder error: \$e");
      return -1;
    }
  }

  Future<List<Map<String, dynamic>>> getReminders() async {
    try {
      final db = await database;
      return await db.query(
        'reminders',
        orderBy: 'timestamp DESC',
      );
    } catch (e) {
      debugPrint("SQLite getReminders error: \$e");
      return [];
    }
  }

  // --- Settings & Users (Dummies for now to satisfy interface) --- //
  Future<int?> saveUser(String phoneNumber) async {
    // Replaced by SQLite - not needed for offline local
    return 1;
  }

  Future<void> saveSettings(int userId, String themeMode, String languageCode, bool offlineMode) async {
    // Replaced by SharedPreferences
  }
}
