import 'package:flutter/material.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

/// Manages the state for the daily session schedule.
///
/// Loads sessions for the selected date from the SQLite database via
/// [SessionRepository] and exposes them to the UI via [ChangeNotifier].
class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository = SessionRepository();
  List<Session> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  List<Session> get sessions => _sessions;
  bool get isLoading => _isLoading;

  /// The most recent error message, or null if the last operation succeeded.
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;

  SessionProvider() {
    loadSessions();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    loadSessions();
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sessions = await _repository.getSessionsForDate(_selectedDate);
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      _errorMessage = 'فشل تحميل الجلسات: $e';
      _sessions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSession(Session session) async {
    try {
      _errorMessage = null;
      await _repository.insertSession(session);
      await loadSessions();
    } catch (e) {
      debugPrint('Error adding session: $e');
      _errorMessage = 'فشل إضافة الجلسة: $e';
      notifyListeners();
    }
  }

  Future<void> updateSession(Session session) async {
    try {
      _errorMessage = null;
      await _repository.updateSession(session);
      await loadSessions();
    } catch (e) {
      debugPrint('Error updating session: $e');
      _errorMessage = 'فشل تحديث الجلسة: $e';
      notifyListeners();
    }
  }

  Future<void> deleteSession(int id) async {
    try {
      _errorMessage = null;
      await _repository.deleteSession(id);
      await loadSessions();
    } catch (e) {
      debugPrint('Error deleting session: $e');
      _errorMessage = 'فشل حذف الجلسة: $e';
      notifyListeners();
    }
  }
}
