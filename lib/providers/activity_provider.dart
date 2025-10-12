import 'package:flutter/foundation.dart';
import 'package:offline_first_app/models/activity_progress.dart';
import 'package:offline_first_app/services/activity_service.dart';

class ActivityProvider with ChangeNotifier {
  final ActivityService _service = ActivityService();
  List<ActivityProgress> _items = [];
  bool _isLoading = false;
  String? _error;

  List<ActivityProgress> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? v) { _error = v; notifyListeners(); }

  Future<void> loadActivity(String classroomId) async {
    _setLoading(true);
    try {
      _items = await _service.getActivityProgress(classroomId);
      _setError(null);
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}
