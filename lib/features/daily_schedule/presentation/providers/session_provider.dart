import 'package:flutter/foundation.dart';

import '../../../../core/utils/arabic_format.dart';
import '../../data/models/session_model.dart';
import '../../data/repositories/session_repository.dart';

class SessionProvider extends ChangeNotifier {
  final SessionRepository _repository;
  List<Session> _sessions = [];
  bool _isLoading = false;
  bool _disposed = false;
  int _request = 0;
  String? _errorMessage;
  String _query = '';
  DateTime _selectedDate = ArabicFormat.day(DateTime.now());
  List<Session> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime get selectedDate => _selectedDate;
  String get searchQuery => _query;

  SessionProvider({SessionRepository? repository, bool autoLoad = true})
    : _repository = repository ?? SessionRepository() {
    if (autoLoad) loadSessions();
  }
  void setSelectedDate(DateTime date) {
    _selectedDate = ArabicFormat.day(date);
    _query = '';
    loadSessions();
  }

  void search(String query) {
    _query = query.trim();
    loadSessions();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadSessions() async {
    if (_disposed) return;
    final request = ++_request;
    final date = _selectedDate;
    final query = _query;
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      final result = query.isEmpty
          ? await _repository.getSessionsForDate(date)
          : await _repository.searchSessions(query);
      if (_disposed || request != _request) return;
      _sessions = result;
    } catch (e) {
      if (_disposed || request != _request) return;
      debugPrint('Session load failed: $e');
      _errorMessage = 'تعذر تحميل الجلسات. أعد المحاولة.';
      _sessions = [];
    } finally {
      if (!_disposed && request == _request) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<bool> _write(Future<int> Function() operation) async {
    if (_disposed) return false;
    try {
      _errorMessage = null;
      if (await operation() != 1) throw StateError('Record no longer exists');
      await loadSessions();
      return true;
    } catch (e) {
      debugPrint('Session write failed: $e');
      _errorMessage = 'تعذر حفظ التغيير. أعد المحاولة.';
      _notify();
      return false;
    }
  }

  Future<bool> addSession(Session session) =>
      _write(() async => await _repository.insertSession(session) > 0 ? 1 : 0);
  Future<bool> updateSession(Session session) =>
      _write(() => _repository.updateSession(session));
  Future<bool> deleteSession(int id) =>
      _write(() => _repository.deleteSession(id));
  @override
  void dispose() {
    _disposed = true;
    _request++;
    super.dispose();
  }
}
