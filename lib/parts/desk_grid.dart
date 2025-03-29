import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/desk_assignment_model.dart';

class DeskGrid extends StatefulWidget {
  const DeskGrid({super.key});

  @override
  DeskGridState createState() => DeskGridState();
}

class DeskGridState extends State<DeskGrid> {
  final FirebaseService _firebaseService = FirebaseService();
  List<DeskAssignment> _deskAssignments = [];
  final Map<String, bool> _userPresenceStatus = {};

  @override
  void initState() {
    super.initState();
    _loadDeskAssignments();
  }

  Future<void> _loadDeskAssignments() async {
    // Load desk assignments
    final deskAssignments = await _firebaseService.getDeskAssignments();

    setState(() {
      _deskAssignments = deskAssignments;
    });

    // Subscribe to status updates for each assigned user
    for (var assignment in deskAssignments) {
      if (assignment.userId.isNotEmpty) {
        _listenToUserPresence(assignment.userId);
      }
    }
  }

  void _listenToUserPresence(String userId) {
    _firebaseService.userPresenceStream(userId).listen((isPresent) {
      if (mounted) {
        setState(() {
          _userPresenceStatus[userId] = isPresent;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we have 10 desk positions (5x2 grid)
    final int totalDesks = 10;

    // If there are fewer than 10 desk assignments, fill with empty ones
    final padded = List<DeskAssignment>.from(_deskAssignments);
    if (padded.length < totalDesks) {
      final emptyCount = totalDesks - padded.length;
      for (int i = 0; i < emptyCount; i++) {
        padded.add(DeskAssignment(
          deskId: 'empty_${padded.length}',
          position: padded.length,
          userId: '',
          userName: '',
        ));
      }
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 2.0,
        crossAxisSpacing: 20,
        mainAxisSpacing: 16,
      ),
      itemCount: totalDesks,
      itemBuilder: (context, index) {
        final desk = index < padded.length ? padded[index] : null;

        if (desk == null) {
          return _buildEmptyDesk();
        }

        // Determine if this desk's assigned user is present
        final isPresent = desk.userId.isNotEmpty &&
            _userPresenceStatus.containsKey(desk.userId) &&
            _userPresenceStatus[desk.userId] == true;

        return _buildDeskItem(desk, isPresent);
      },
    );
  }

  Widget _buildDeskItem(DeskAssignment desk, bool isPresent) {
    final hasUser = desk.userId.isNotEmpty;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasUser
              ? (isPresent ? Colors.green.shade300 : Colors.grey.shade400)
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: hasUser
              ? (isPresent
              ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade50, Colors.green.shade100],
          )
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade100, Colors.grey.shade200],
          )
          )
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade100, Colors.grey.shade100],
          ),
        ),
        child: Stack(
          children: [
            if (hasUser)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green : Colors.red.shade300,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isPresent
                            ? Colors.green.withOpacity(0.5)
                            : Colors.red.shade300.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasUser) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPresent ? Colors.green.shade100 : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isPresent ? Colors.green.shade400 : Colors.grey.shade500,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: isPresent ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desk.userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isPresent ? Colors.black87 : Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPresent
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPresent
                              ? Colors.green.shade300
                              : Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isPresent ? '入室中' : '退室中',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isPresent ? Colors.green.shade800 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ] else
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.desk,
                          size: 24,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '未割当',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDesk() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.desk,
              size: 24,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              '未割当',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}