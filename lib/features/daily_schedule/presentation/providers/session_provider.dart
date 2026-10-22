import 'package:flutter/material.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository = SessionRepository();
  List<Session> _sessions = [];
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  List<Session> get sessions => _sessions;
  bool get isLoading => _isLoading;
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
    notifyListeners();

    try {
      _sessions = await _repository.getSessionsForDate(_selectedDate);
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      _sessions = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSession(Session session) async {
    await _repository.insertSession(session);
    await loadSessions();
  }

  Future<void> updateSession(Session session) async {
    await _repository.updateSession(session);
    await loadSessions();
  }

  Future<void> deleteSession(int id) async {
    await _repository.deleteSession(id);
    await loadSessions();
  }
}