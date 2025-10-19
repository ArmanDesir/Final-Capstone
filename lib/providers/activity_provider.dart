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

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? v) {
    _error = v;
    notifyListeners();
  }

  Future<void> loadActivity(String classroomId) async {
    _setLoading(true);
    try {
      debugPrint('📡 Fetching activity logs for classroom: $classroomId ...');
      final result = await _service.getActivityProgress(classroomId);

      debugPrint('✅ Activity logs fetched: ${result.length} record(s)');
      if (result.isEmpty) {
        debugPrint('ℹ️ No recent activity found for this classroom.');
      } else {
        for (final item in result.take(10)) {
          debugPrint(
            '👤 ${item.userName ?? "Unknown User"} '
                '→ ${item.entityType} (${item.entityTitle ?? "Untitled"}) | '
                'Score: ${item.score ?? "-"} | '
                'Attempt: ${item.attempt ?? "-"} | '
                'Tries: ${item.tries ?? "-"} | '
                'Status: ${item.status ?? "N/A"} | '
                'Created: ${item.createdAt}',
          );
        }
        if (result.length > 10) {
          debugPrint('… (showing first 10 of ${result.length} total)');
        }
      }

      _items = result;
      _setError(null);
    } catch (e, stack) {
      debugPrint('❌ Error loading activity logs: $e');
      debugPrintStack(label: 'ActivityProvider.loadActivity', stackTrace: stack);
      _setError(e.toString());
    } finally {
      _setLoading(false);
      debugPrint('📦 loadActivity() finished\n');
    }
  }
}
