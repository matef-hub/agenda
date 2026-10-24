import '../security/secret_vault.dart';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal() : _path = null, _secure = true;
  DatabaseHelper.forTesting(String path) : _path = path, _secure = false;
  final String? _path;
  final bool _secure;
  Future<Database>? _opening;
  static const tables = [
    'sessions',
    'personal_info',
    'powers_of_attorney',
    'bailiff_papers',
    'admin_notes',
  ];

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    try {
      return _database = await _initDatabase();
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> close() async {
    final db = _database ?? await _opening;
    await db?.close();
    _database = null;
    _opening = null;
  }

  Future<Database> _initDatabase() async {
    try {
      String path;
      if (_path != null) {
        path = _path;
      } else if (kIsWeb) {
        // على الويب، نستخدم اسم القاعدة مباشرة دون مسار نظام الملفات
        path = 'judicial_agenda.db';
      } else {
        final dbPath = await getDatabasesPath();
        path = join(dbPath, 'judicial_agenda.db');
      }
      return await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          if (_secure) {
            await db.transaction((txn) async {
              await SecretVault.migrate((row) async {
                await txn.update(
                  'personal_info',
                  row,
                  where: 'id = ?',
                  whereArgs: [row['id']],
                );
              }, await txn.query('personal_info'));
            });
          }
        },
      );
    } catch (e) {
      debugPrint('❌ Database initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // جدول الجلسات اليومية
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        court_name TEXT NOT NULL,
        circuit TEXT NOT NULL,
        case_number TEXT NOT NULL,
        case_year INTEGER NOT NULL,
        client_name TEXT NOT NULL,
        client_capacity TEXT,
        opponent_name TEXT NOT NULL,
        opponent_capacity TEXT,
        previous_session TEXT,
        decision TEXT,
        notes TEXT,
        session_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول البيانات الشخصية
    await db.execute('''
      CREATE TABLE personal_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        home_address TEXT,
        office_address TEXT,
        home_tel TEXT,
        office_tel TEXT,
        mobile TEXT,
        id_card_no TEXT,
        passport_no TEXT,
        car_license_no TEXT,
        driving_license_no TEXT,
        bank_account_no TEXT,
        credit_card_no TEXT,
        email TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // جدول التوكيلات
    await db.execute('''
      CREATE TABLE powers_of_attorney (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_name TEXT NOT NULL,
        poa_number TEXT NOT NULL,
        notarization_office TEXT,
        poa_type TEXT,
        poa_date TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول أوراق المحضرين
    await db.execute('''
      CREATE TABLE bailiff_papers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reference_number TEXT NOT NULL,
        bailiffs_office TEXT NOT NULL,
        client_name TEXT NOT NULL,
        delivery_date TEXT,
        hearing_date TEXT,
        status TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // جدول الأعمال الإدارية / الملاحظات
    await db.execute('''
      CREATE TABLE admin_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        content TEXT NOT NULL,
        is_completed INTEGER DEFAULT 0,
        note_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await _indexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _indexes(db);
  }

  Future<void> _indexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(session_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_admin_date ON admin_notes(note_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_poa_client ON powers_of_attorney(client_name)',
    );
  }

  void _checkTable(String table) {
    if (!tables.contains(table)) throw ArgumentError('Unknown table');
  }

  Future<Map<String, dynamic>> prepare(
    String table,
    Map<String, dynamic> row,
  ) async {
    _checkTable(table);
    return _secure && table == 'personal_info'
        ? SecretVault.protect(row)
        : Map.of(row);
  }

  Future<List<Map<String, dynamic>>> decode(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    return _secure && table == 'personal_info'
        ? Future.wait(rows.map(SecretVault.reveal))
        : rows;
  }
  // --- Generic CRUD Methods ---

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(table, await prepare(table, row));
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    _checkTable(table);
    return decode(table, await db.query(table, orderBy: 'id DESC'));
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table,
    String where,
    List<dynamic> whereArgs,
  ) async {
    final db = await database;
    _checkTable(table);
    return decode(
      table,
      await db.query(
        table,
        where: where,
        whereArgs: whereArgs,
        orderBy: table == 'sessions'
            ? 'session_date ASC, court_name ASC, id ASC'
            : 'id DESC',
      ),
    );
  }

  Future<int> update(String table, Map<String, dynamic> row, int id) async {
    final db = await database;
    return await db.update(
      table,
      await prepare(table, row),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    _checkTable(table);
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  // دالة مساعدة لحذف كل البيانات (للاختبار فقط)
  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }
}
