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
    query = ArabicFormat.normalize(query)
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    final db = await _dbHelper.database;
    const fields = [
      'client_name',
      'opponent_name',
      'case_number',
      'court_name',
    ];
    String normalized(String field) {
      var result = field;
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      const persian = '۰۱۲۳۴۵۶۷۸۹';
      for (var i = 0; i < 10; i++) {
        result =
            "replace(replace($result, '${arabic[i]}', '$i'), '${persian[i]}', '$i')";
      }
      return result;
    }

    final maps = await db.query(
      'sessions',
      orderBy: 'session_date ASC, court_name ASC, id ASC',
      where: fields
          .map((field) => "${normalized(field)} LIKE ? ESCAPE '\\'")
          .join(' OR '),
      whereArgs: fields.map((_) => '%$query%').toList(),
    );
    return maps.map(Session.fromMap).toList();
  }

  Future<List<Session>> caseHistory(Session session) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sessions',
      where: 'court_name = ? AND case_number = ? AND case_year = ? AND circuit = ?',
      whereArgs: [session.courtName, session.caseNumber, session.caseYear],
      orderBy: 'session_date DESC, id DESC',
    );
    return rows.map(Session.fromMap).toList();
  }

  /// Preserves the old hearing and records the next one in a single transaction.
  Future<void> postpone(Session session, DateTime nextDate) async {
    if (session.id == null ||
        !ArabicFormat.day(nextDate)
            .isAfter(ArabicFormat.day(session.sessionDate))) {
      throw ArgumentError('The next hearing must be later');
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [session.id],
      );
      if (existing.isEmpty) throw StateError('Missing original session');
      final original = Session.fromMap(existing.single);
      if (original.updatedAt != session.updatedAt) {
        throw StateError('Session changed; reload first');
      }
      final now = DateTime.now().toIso8601String();
      final decision = 'تأجيل إلى ${ArabicFormat.date(nextDate)}';
      await txn.update(
        'sessions',
        {'decision': decision, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [session.id],
      );
      final next = original.toMap()..remove('id');
      next.addAll({
        'session_date': ArabicFormat.dateKey(nextDate),
        'previous_session':
            '${ArabicFormat.date(original.sessionDate)} — $decision',
        'decision': '',
        'created_at': now,
        'updated_at': now,
      });
      await txn.insert('sessions', next);
    });
  }
}
