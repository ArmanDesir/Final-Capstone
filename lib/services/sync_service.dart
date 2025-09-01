import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../services/firebase_service.dart';
import '../models/user.dart';
import '../models/task.dart';

import 'package:logger/logger.dart';

class SyncService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final FirebaseService _firebaseService = FirebaseService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncTimer;
  bool _isOnline = false;

  SyncService() {
    _initializeConnectivity();
    _startPeriodicSync();
  }

  void _initializeConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      if (_isOnline) {
        _performSync();
      }
    });
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        _performSync();
      }
    });
  }

  Future<void> _performSync() async {
    try {
      await _syncTasksToFirebase();
      await _syncTasksFromFirebase();
    } catch (e) {
      Logger().e('Error during sync: $e');
    }
  }

  Future<Task> createTask(Task task) async {
    await _databaseHelper.insertTask(task);
    if (_isOnline) {
      try {
        String firebaseId = await _firebaseService.createTask(task);
        Task updatedTask = task.copyWith(
          firebaseId: firebaseId,
          isSynced: true,
        );
        await _databaseHelper.updateTask(updatedTask);
        return updatedTask;
      } catch (e) {
        Logger().e('Error syncing task to Firebase: $e');
      }
    }

    return task;
  }

  Future<Task?> updateTask(Task task) async {
    await _databaseHelper.updateTask(task);

    if (_isOnline && task.firebaseId != null) {
      try {
        await _firebaseService.updateTask(task);
        Task updatedTask = task.copyWith(isSynced: true);
        await _databaseHelper.updateTask(updatedTask);
        return updatedTask;
      } catch (e) {
        Logger().e('Error syncing task update to Firebase: $e');
        Task unsyncedTask = task.copyWith(isSynced: false);
        await _databaseHelper.updateTask(unsyncedTask);
      }
    }

    return task;
  }

  Future<void> deleteTask(String taskId) async {
    Task? task = await _databaseHelper.getTaskById(taskId);
    if (task != null) {
      await _databaseHelper.deleteTask(taskId);

      if (_isOnline && task.firebaseId != null) {
        try {
          await _firebaseService.deleteTask(task.firebaseId!);
        } catch (e) {
          Logger().e('Error deleting task from Firebase: $e');
        }
      }
    }
  }

  Future<List<Task>> getTasksByUserId(String userId) async {

    List<Task> localTasks = await _databaseHelper.getTasksByUserId(userId);

    if (_isOnline) {
      try {
        List<Task> firebaseTasks = await _firebaseService.getTasksByUserId(
          userId,
        );
        await _mergeTasks(localTasks, firebaseTasks, userId);
        return await _databaseHelper.getTasksByUserId(userId);
      } catch (e) {
        Logger().e('Error syncing tasks from Firebase: $e');
      }
    }

    return localTasks;
  }

  Future<void> _mergeTasks(
    List<Task> localTasks,
    List<Task> firebaseTasks,
    String userId,
  ) async {
    Map<String, Task> localTaskMap = {
      for (Task task in localTasks) task.id: task,
    };
    Map<String, Task> firebaseTaskMap = {
      for (Task task in firebaseTasks) task.firebaseId ?? task.id: task,
    };

    for (Task firebaseTask in firebaseTasks) {
      bool existsLocally = localTaskMap.values.any(
        (localTask) => localTask.firebaseId == firebaseTask.firebaseId,
      );

      if (!existsLocally) {
        Task newTask = firebaseTask.copyWith(
          id: firebaseTask.firebaseId ?? firebaseTask.id,
          userId: userId,
          isSynced: true,
        );
        await _databaseHelper.insertTask(newTask);
      }
    }

    for (Task localTask in localTasks) {
      if (localTask.firebaseId != null) {
        Task? firebaseTask = firebaseTaskMap[localTask.firebaseId];
        if (firebaseTask != null &&
            firebaseTask.updatedAt.isAfter(localTask.updatedAt)) {
          Task updatedTask = firebaseTask.copyWith(
            id: localTask.id,
            userId: userId,
            isSynced: true,
          );
          await _databaseHelper.updateTask(updatedTask);
        }
      }
    }
  }

  Future<void> _syncTasksToFirebase() async {
    List<Task> unsyncedTasks = await _databaseHelper.getUnsyncedTasks();

    for (Task task in unsyncedTasks) {
      try {
        if (task.firebaseId == null) {
          String firebaseId = await _firebaseService.createTask(task);
          Task updatedTask = task.copyWith(
            firebaseId: firebaseId,
            isSynced: true,
          );
          await _databaseHelper.updateTask(updatedTask);
        } else {
          await _firebaseService.updateTask(task);
          Task updatedTask = task.copyWith(isSynced: true);
          await _databaseHelper.updateTask(updatedTask);
        }
      } catch (e) {
        Logger().e('Error syncing task to Firebase: $e');
      }
    }
  }

  Future<void> _syncTasksFromFirebase() async {
  }

  Future<User> createUser(User user) async {
    await _databaseHelper.insertUser(user);

    if (_isOnline) {
      try {
        await _firebaseService.createUser(user);
        User updatedUser = user.copyWith(
          isOnline: true,
          lastSyncTime: DateTime.now().toIso8601String(),
        );
        await _databaseHelper.updateUser(updatedUser);
        return updatedUser;
      } catch (e) {
        Logger().e('Error syncing user to Firebase: $e');
      }
    }

    return user;
  }

  Future<User?> updateUser(User user) async {

    if (_isOnline) {
      try {
        await _firebaseService.updateUser(user);
        User updatedUser = user.copyWith(
          isOnline: true,
          lastSyncTime: DateTime.now().toIso8601String(),
        );
        await _databaseHelper.updateUser(updatedUser);
        return updatedUser;
      } catch (e) {
        Logger().e('Error syncing user update to Firebase: $e');
      }
    }

    return user;
  }

  Future<User?> getUserById(String id) async {
    User? localUser = await _databaseHelper.getUserById(id);
    if (_isOnline) {
      try {
        User? firebaseUser = await _firebaseService.getUserById(id);
        if (firebaseUser != null) {
          await _databaseHelper.updateUser(firebaseUser);
          return firebaseUser;
        }
      } catch (e) {
        Logger().e('Error syncing user from Firebase: $e');
      }
    }

    return localUser;
  }

  Future<void> updateUserClassroom(String userId, String? classroomId) async {
    User? user = await _databaseHelper.getUserById(userId);
    if (user != null) {
      User updatedUser = user.copyWith(
        classroomId: classroomId,
        updatedAt: DateTime.now(),
      );
      await _databaseHelper.updateUser(updatedUser);
      if (_isOnline) {
        try {
          await _firebaseService.updateUser(updatedUser);
        } catch (e) {
          Logger().e('Error syncing user classroom update to Firebase: $e');
        }
      }
    }
  }

  bool get isOnline => _isOnline;

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
  }
}
