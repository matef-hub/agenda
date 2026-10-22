import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'judicial_agenda.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // التعامل مع تحديثات قاعدة البيانات مستقبلاً
    if (oldVersion < newVersion) {
      // مثال: ALTER TABLE ...
    }
  }

  // --- Generic CRUD Methods ---

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(table, row);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<List<Map<String, dynamic>>> queryWhere(String table, String where, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> row, int id) async {
    final db = await database;
    return await db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(String table, int id) async {
    final db = await database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
  
  // دالة مساعدة لحذف كل البيانات (للاختبار فقط)
  Future<void> clearTable(String table) async {
    final db = await database;
    await db.delete(table);
  }
}