import '../../../../core/utils/arabic_format.dart';
import '../../../../core/database/database_helper.dart';
import '../models/session_model.dart';
import '../models/hearing_suggestion.dart';

class SessionRepository {
  final DatabaseHelper _dbHelper;
  SessionRepository({DatabaseHelper? database})
    : _dbHelper = database ?? DatabaseHelper();

  // Identifiers passed here are internal column names, never user input.
  static String _normalizedDigitsSql(String field) {
    var result = field;
    for (final digit in '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹'.split('')) {
      result = "replace($result, '$digit', '${ArabicFormat.normalize(digit)}')";
    }
    return result;
  }

  Future<List<HearingSuggestion>> findPreviousHearings(
    String caseNumber,
    String caseYear,
  ) async {
    final number = ArabicFormat.normalize(caseNumber).trim();
    final yearText = ArabicFormat.normalize(caseYear).replaceAll(RegExp(r'\s+'), '');
    if (number.isEmpty || !RegExp(r'^\d{1,4}\s*ق?$').hasMatch(yearText)) {
      return [];
    }
    final Object year = int.tryParse(yearText) ?? yearText;
    final db = await _dbHelper.database;
    // SQLite's default trim removes only spaces. Match Dart's surrounding
    // whitespace trimming for older records too, without rewriting them.
    const whitespace =
        ' \t\n\r\u000B\u000C\u0085\u00A0\u1680'
        '\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A'
        '\u2028\u2029\u202F\u205F\u3000\uFEFF';
    final rows = await db.query(
      'sessions',
      where:
          'case_year = ? AND trim(${_normalizedDigitsSql('case_number')}, ?) = ?',
      whereArgs: [year, whitespace, number],
      orderBy: 'session_date DESC, id DESC',
    );
    return HearingSuggestion.group(rows.map(Session.fromMap));
  }

  Future<List<String>> capacities() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT client_capacity AS capacity FROM sessions UNION SELECT opponent_capacity AS capacity FROM sessions',
    );
    return rows
        .map((row) => (row['capacity'] as String? ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

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
    final maps = await db.query(
      'sessions',
      orderBy: 'session_date ASC, court_name ASC, id ASC',
      where: fields
          .map((field) => "${_normalizedDigitsSql(field)} LIKE ? ESCAPE '\\'")
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
      whereArgs: [
        session.courtName,
        session.caseNumber,
        session.caseYear,
        session.circuit,
      ],
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
