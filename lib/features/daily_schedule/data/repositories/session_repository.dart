import '../../../../core/utils/arabic_format.dart';
import '../../../../core/database/database_helper.dart';
import '../models/session_model.dart';

class SessionRepository {
  final DatabaseHelper _dbHelper;
  SessionRepository({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper();

  // إضافة جلسة جديدة
  Future<int> insertSession(Session session) async {
    return await _dbHelper.insert('sessions', session.toMap());
  }

  // جلب جميع الجلسات ليوم معين
  Future<List<Session>> getSessionsForDate(DateTime date) async {
    // استخدام نطاق تاريخي (Range Query) للاستفادة من الفهارس (Indexes)
    // بدلاً من LIKE الذي يمنع استخدام الفهرس ويسبب بطئاً مع زيادة البيانات.
    final String dateStrStart = ArabicFormat.dateKey(date);
    final String dateStrEnd = ArabicFormat.dateKey(
      ArabicFormat.shiftDay(date, 1),
    );

    final List<Map<String, dynamic>> maps = await _dbHelper.queryWhere(
      'sessions',
      'session_date >= ? AND session_date < ?',
      [dateStrStart, dateStrEnd],
    );

    return List.generate(maps.length, (i) {
      return Session.fromMap(maps[i]);
    });
  }

  // جلب جلسة واحدة حسب المعرف
  Future<Session?> getSession(int id) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.queryWhere(
      'sessions',
      'id = ?',
      [id],
    );
    if (maps.isNotEmpty) {
      return Session.fromMap(maps.first);
    }
    return null;
  }

  // تحديث جلسة
  Future<int> updateSession(Session session) async {
    if (session.id == null) return 0;
    return await _dbHelper.update('sessions', session.toMap(), session.id!);
  }

  // حذف جلسة
  Future<int> deleteSession(int id) async {
    return await _dbHelper.delete('sessions', id);
  }

  // البحث عن جلسات (باسم الموكل أو رقم القضية)
  Future<List<Session>> searchSessions(String query) async {
    query = ArabicFormat.normalize(query);
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'session_date ASC, court_name ASC, id ASC',
      where: 'client_name LIKE ? OR case_number LIKE ? OR court_name LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) {
      return Session.fromMap(maps[i]);
    });
  }
}
