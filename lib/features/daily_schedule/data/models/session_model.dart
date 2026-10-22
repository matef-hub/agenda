/// Data model for a court session entry in the judicial agenda.
///
/// Maps to the `sessions` table in the SQLite database.
class Session {
  final int? id;
  final String courtName; // اسم المحكمة
  final String circuit; // الدائرة
  final String caseNumber; // رقم الدعوى
  final int caseYear; // سنة الدعوى
  final String clientName; // اسم الموكل
  final String clientCapacity; // صفة الموكل (مدعي، مدعى عليه، إلخ)
  final String opponentName; // اسم الخصم
  final String opponentCapacity; // صفة الخصم
  final String previousSession; // تفاصيل الجلسة السابقة
  final String decision; // القرار
  final String notes; // ملاحظات إضافية
  final DateTime sessionDate; // تاريخ الجلسة (يستخدم للفلترة اليومية)
  final DateTime createdAt;
  final DateTime updatedAt;

  Session({
    this.id,
    required this.courtName,
    required this.circuit,
    required this.caseNumber,
    required this.caseYear,
    required this.clientName,
    required this.clientCapacity,
    required this.opponentName,
    required this.opponentCapacity,
    required this.previousSession,
    required this.decision,
    required this.notes,
    required this.sessionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// تحويل كائن Session إلى Map لحفظه في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'court_name': courtName,
      'circuit': circuit,
      'case_number': caseNumber,
      'case_year': caseYear,
      'client_name': clientName,
      'client_capacity': clientCapacity,
      'opponent_name': opponentName,
      'opponent_capacity': opponentCapacity,
      'previous_session': previousSession,
      'decision': decision,
      'notes': notes,
      'session_date': sessionDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// إنشاء كائن Session من Map مسترجع من قاعدة البيانات.
  ///
  /// Handles nullable columns (`client_capacity`, `opponent_capacity`,
  /// `previous_session`, `decision`, `notes`) by defaulting to an empty
  /// string when the database value is null.
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as int?,
      courtName: map['court_name'] as String? ?? '',
      circuit: map['circuit'] as String? ?? '',
      caseNumber: map['case_number'] as String? ?? '',
      caseYear: map['case_year'] as int? ?? DateTime.now().year,
      clientName: map['client_name'] as String? ?? '',
      clientCapacity: map['client_capacity'] as String? ?? '',
      opponentName: map['opponent_name'] as String? ?? '',
      opponentCapacity: map['opponent_capacity'] as String? ?? '',
      previousSession: map['previous_session'] as String? ?? '',
      decision: map['decision'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      sessionDate: DateTime.parse(map['session_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// إنشاء نسخة معدلة من الجلسة (للتحديث).
  ///
  /// Preserves [createdAt] from the original session and auto-updates
  /// [updatedAt] to the current time unless explicitly overridden.
  Session copyWith({
    int? id,
    String? courtName,
    String? circuit,
    String? caseNumber,
    int? caseYear,
    String? clientName,
    String? clientCapacity,
    String? opponentName,
    String? opponentCapacity,
    String? previousSession,
    String? decision,
    String? notes,
    DateTime? sessionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      courtName: courtName ?? this.courtName,
      circuit: circuit ?? this.circuit,
      caseNumber: caseNumber ?? this.caseNumber,
      caseYear: caseYear ?? this.caseYear,
      clientName: clientName ?? this.clientName,
      clientCapacity: clientCapacity ?? this.clientCapacity,
      opponentName: opponentName ?? this.opponentName,
      opponentCapacity: opponentCapacity ?? this.opponentCapacity,
      previousSession: previousSession ?? this.previousSession,
      decision: decision ?? this.decision,
      notes: notes ?? this.notes,
      sessionDate: sessionDate ?? this.sessionDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
