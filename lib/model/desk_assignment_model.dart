class DeskAssignment {
  final String deskId;
  final int position;
  final String userId;
  final String userName;

  DeskAssignment({
    required this.deskId,
    required this.position,
    required this.userId,
    required this.userName,
  });

  // Create from Firestore document
  factory DeskAssignment.fromMap(Map<String, dynamic> map, String documentId) {
    return DeskAssignment(
      deskId: documentId,
      position: map['position'] as int,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'position': position,
      'userId': userId,
      'userName': userName,
    };
  }

  // Copy with method for easy modification
  DeskAssignment copyWith({
    String? deskId,
    int? position,
    String? userId,
    String? userName,
  }) {
    return DeskAssignment(
      deskId: deskId ?? this.deskId,
      position: position ?? this.position,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }
}