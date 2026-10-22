import '../../../../core/database/database_helper.dart';
import '../models/session_model.dart';

class SessionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // إضافة جلسة جديدة
  Future<int> insertSession(Session session) async {
    return await _dbHelper.insert('sessions', session.toMap());
  }

  // جلب جميع الجلسات ليوم معين
  Future<List<Session>> getSessionsForDate(DateTime date) async {
    // تنسيق التاريخ للمقارنة (YYYY-MM-DD)
    final String dateStr = date.toIso8601String().split('T')[0];
    
    // استخدام LIKE للمقارنة لأن session_date مخزن كـ ISO8601 string
    // أو يمكننا مقارنة الجزء الأول فقط.
    // بما أننا نخزن ISO8601 كامل، سنستخدم substr أو like.
    // الطريقة الأبسط والأكثر موثوقية مع SQLite هي مقارنة النصوص إذا كان التنسيق ثابتاً.
    // لكن toIso8601String يعطي وقتاً أيضاً.
    // الحل: جلب كل شيء وتصفية في Dart، أو استخدام query مع where clause دقيق.
    // لنفترض أننا نريد الكفاءة، سنستخدم where clause على التاريخ.
    // ملاحظة: session_date في قاعدة البيانات هو TEXT (ISO8601).
    // مثال: 2026-10-22T10:00:00.000
    // نريد كل ما يبدأ بـ 2026-10-22
    
    final List<Map<String, dynamic>> maps = await _dbHelper.queryWhere(
      'sessions',
      "session_date LIKE ?",
      ['$dateStr%'],
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
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'client_name LIKE ? OR case_number LIKE ? OR court_name LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
    return List.generate(maps.length, (i) {
      return Session.fromMap(maps[i]);
    });
  }
}