import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:exit_entry_system/model/desk_assignment_model.dart';
import 'package:exit_entry_system/model/user_model.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _logsCollection => _firestore.collection('entry_logs');
  CollectionReference get _desksCollection => _firestore.collection('desks');

  // Initialize Firebase (call this at app startup)
  Future<void> initializeFirebase() async {
    try {
      // This function can be expanded with initialization logic
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Firebase: $e');
      rethrow;
    }
  }

  // Get a user by QR code
  Future<UserModel?> getUserByQRCode(String qrCode) async {
    try {
      final snapshot = await _usersCollection
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      return UserModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      debugPrint('Error getting user by QR code: $e');
      rethrow;
    }
  }


  // 入退室ログエントリを作成
  Future<void> createEntryLog(String userId, String userName, bool isEntry) async {
    try {
      // Create a log entry
      final logEntry = EntryLogModel(
        id: '', // Firestore will generate ID
        userId: userId,
        userName: userName,
        timestamp: DateTime.now(),
        isEntry: isEntry,
      );

      await _logsCollection.add(logEntry.toMap());
    } catch (e) {
      debugPrint('Error creating entry log: $e');
      rethrow;
    }
  }

  // Get a user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();

      if (!doc.exists) {
        return null;
      }

      return UserModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      rethrow;
    }
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      ))
          .toList();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      rethrow;
    }
  }

  // Create a new user
  Future<String> createUser(UserModel user) async {
    try {
      // Check if QR code is already in use
      final existingUser = await getUserByQRCode(user.qrCode);
      if (existingUser != null) {
        throw Exception('このQRコードは既に使用されています');
      }

      final docRef = await _usersCollection.add(user.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  // Update an existing user
  Future<void> updateUser(UserModel user) async {
    try {
      // Check if QR code is already in use by another user
      final existingUser = await getUserByQRCode(user.qrCode);
      if (existingUser != null && existingUser.id != user.id) {
        throw Exception('このQRコードは既に使用されています');
      }

      await _usersCollection.doc(user.id).update(user.toMap());
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  // Delete a user
  Future<void> deleteUser(String userId) async {
    try {
      // First, remove this user from any desk assignments
      final desksSnapshot = await _desksCollection
          .where('userId', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();

      for (var doc in desksSnapshot.docs) {
        batch.update(doc.reference, {
          'userId': '',
          'userName': '',
        });
      }

      // Then delete the user
      batch.delete(_usersCollection.doc(userId));

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  // Toggle user presence and log entry/exit
  Future<bool> toggleUserPresence(String qrCode) async {
    try {
      // Get user by QR code
      final user = await getUserByQRCode(qrCode);
      if (user == null) {
        throw Exception('ユーザーが見つかりません');
      }

      final isNowPresent = !user.isPresent;
      final now = DateTime.now();

      // Update user presence status
      final updatedUser = user.copyWith(
        isPresent: isNowPresent,
        lastEntryTime: isNowPresent ? now : user.lastEntryTime,
        lastExitTime: !isNowPresent ? now : user.lastExitTime,
      );

      // Create a log entry
      final logEntry = EntryLogModel(
        id: '', // Firestore will generate ID
        userId: user.id,
        userName: user.name,
        timestamp: now,
        isEntry: isNowPresent,
      );

      // Execute both operations in a batch
      final batch = _firestore.batch();
      batch.update(_usersCollection.doc(user.id), updatedUser.toMap());
      batch.set(_logsCollection.doc(), logEntry.toMap());

      await batch.commit();

      return isNowPresent; // Return the new status (true for entry, false for exit)
    } catch (e) {
      debugPrint('Error toggling user presence: $e');
      rethrow;
    }
  }

  // Get entry logs with optional filtering
  Future<List<EntryLogModel>> getEntryLogs({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _logsCollection.orderBy('timestamp', descending: true);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        // Add one day to include the end date
        final nextDay = endDate.add(const Duration(days: 1));
        query = query.where('timestamp', isLessThan: nextDay);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => EntryLogModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      ))
          .toList();
    } catch (e) {
      debugPrint('Error getting entry logs: $e');
      rethrow;
    }
  }

  // Stream for user presence status
  Stream<bool> userPresenceStream(String userId) {
    return _usersCollection
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return false;
      }
      final data = snapshot.data() as Map<String, dynamic>;
      return data['isPresent'] as bool? ?? false;
    });
  }

  // Get desk assignments
  Future<List<DeskAssignment>> getDeskAssignments() async {
    try {
      final snapshot = await _desksCollection
          .orderBy('position')
          .get();

      return snapshot.docs
          .map((doc) => DeskAssignment.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      ))
          .toList();
    } catch (e) {
      debugPrint('Error getting desk assignments: $e');
      rethrow;
    }
  }

  // Update desk assignment
  Future<void> updateDeskAssignment(DeskAssignment desk) async {
    try {
      if (desk.deskId.isEmpty || desk.deskId.startsWith('empty_')) {
        // Create new desk
        await _desksCollection.add(desk.toMap());
      } else {
        // Update existing desk
        await _desksCollection.doc(desk.deskId).update(desk.toMap());
      }
    } catch (e) {
      debugPrint('Error updating desk assignment: $e');
      rethrow;
    }
  }

  // Delete desk assignment
  Future<void> deleteDeskAssignment(String deskId) async {
    try {
      await _desksCollection.doc(deskId).delete();
    } catch (e) {
      debugPrint('Error deleting desk assignment: $e');
      rethrow;
    }
  }

  // Initialize default desk layout if none exists
  Future<void> initializeDefaultDeskLayout() async {
    try {
      final existingDesks = await getDeskAssignments();

      if (existingDesks.isEmpty) {
        final batch = _firestore.batch();

        // Create 10 empty desks in a 5x2 grid
        for (int i = 0; i < 10; i++) {
          final desk = DeskAssignment(
            deskId: '',
            position: i,
            userId: '',
            userName: '',
          );

          final docRef = _desksCollection.doc();
          batch.set(docRef, desk.toMap());
        }

        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error initializing default desk layout: $e');
      rethrow;
    }
  }
}