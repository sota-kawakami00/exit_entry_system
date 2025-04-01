import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String qrCode;
  final bool isPresent;
  final DateTime? lastEntryTime;
  final DateTime? lastExitTime;

  UserModel({
    required this.id,
    required this.name,
    required this.qrCode,
    this.isPresent = false,
    this.lastEntryTime,
    this.lastExitTime,
  });

  // Create from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      qrCode: map['qrCode'] as String? ?? '',
      isPresent: map['isPresent'] as bool? ?? false,
      lastEntryTime: map['lastEntryTime'] != null
          ? (map['lastEntryTime'] as Timestamp).toDate()
          : null,
      lastExitTime: map['lastExitTime'] != null
          ? (map['lastExitTime'] as Timestamp).toDate()
          : null,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'qrCode': qrCode,
      'isPresent': isPresent,
      'lastEntryTime': lastEntryTime,
      'lastExitTime': lastExitTime,
    };
  }

  // Copy with method for easy modification
  UserModel copyWith({
    String? id,
    String? name,
    String? qrCode,
    bool? isPresent,
    DateTime? lastEntryTime,
    DateTime? lastExitTime,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      qrCode: qrCode ?? this.qrCode,
      isPresent: isPresent ?? this.isPresent,
      lastEntryTime: lastEntryTime ?? this.lastEntryTime,
      lastExitTime: lastExitTime ?? this.lastExitTime,
    );
  }
}

// Log entry model for storing entry/exit history
class EntryLogModel {
  final String id;
  final String userId;
  final String userName;
  final DateTime timestamp;
  final bool isEntry; // true for entry, false for exit
  final String? note; // 備考フィールドを追加

  EntryLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.isEntry,
    this.note, // オプショナルパラメータとして追加
  });

  // Create from Firestore document
  factory EntryLogModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EntryLogModel(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isEntry: map['isEntry'] as bool? ?? true,
      note: map['note'] as String?, // FirestoreからNoteフィールドを取得
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp,
      'isEntry': isEntry,
      'note': note, // noteフィールドを追加
    };
  }
}