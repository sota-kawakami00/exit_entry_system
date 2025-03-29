import 'package:exit_entry_system/model/desk_assignment_model.dart';
import 'package:exit_entry_system/model/user_model.dart';
import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:flutter/material.dart';

class DeskLayoutScreen extends StatefulWidget {
  const DeskLayoutScreen({super.key});

  @override
  DeskLayoutScreenState createState() => DeskLayoutScreenState();
}

class DeskLayoutScreenState extends State<DeskLayoutScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<DeskAssignment> _deskAssignments = [];
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load desk assignments
      final desks = await _firebaseService.getDeskAssignments();

      // Load all users for assignment
      final users = await _firebaseService.getAllUsers();

      setState(() {
        _deskAssignments = desks;
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データの読み込みに失敗しました: $e')),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _assignUserToDesk(DeskAssignment desk) async {
    // Prepare a list of users with an "unassign" option at the top
    final items = [
      const DropdownMenuItem<String>(
        value: '',
        child: Text('割り当て解除'),
      ),
      ..._users.map((user) => DropdownMenuItem<String>(
        value: user.id,
        child: Text(user.name),
      )),
    ];

    String? selectedUserId = desk.userId.isEmpty ? null : desk.userId;

    final result = await showDialog<String?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('ユーザーを割り当て'),
              content: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'ユーザー',
                  border: OutlineInputBorder(),
                ),
                value: selectedUserId,
                items: items,
                onChanged: (value) {
                  selectedUserId = value;
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedUserId),
                  child: const Text('割り当て'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        // Get user details if a user was selected
        String userName = '';
        if (result.isNotEmpty) {
          final selectedUser = _users.firstWhere((user) => user.id == result);
          userName = selectedUser.name;
        }

        // Update desk assignment
        final updatedDesk = desk.copyWith(
          userId: result,
          userName: userName,
        );

        await _firebaseService.updateDeskAssignment(updatedDesk);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('机の割り当てを更新しました')),
          );
        }

        // Refresh data
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラーが発生しました: $e')),
          );
        }
      }
    }
  }

  Future<void> _addNewDesk() async {
    try {
      // Create a new desk with the next position
      final newPosition = _deskAssignments.isEmpty
          ? 0
          : _deskAssignments.map((d) => d.position).reduce((a, b) => a > b ? a : b) + 1;

      final newDesk = DeskAssignment(
        deskId: '',
        position: newPosition,
        userId: '',
        userName: '',
      );

      await _firebaseService.updateDeskAssignment(newDesk);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('新しい机を追加しました')),
        );
      }

      // Refresh data
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<void> _deleteDesk(DeskAssignment desk) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('机を削除'),
          content: const Text('この机を削除してもよろしいですか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await _firebaseService.deleteDeskAssignment(desk.deskId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('机を削除しました')),
          );
        }

        // Refresh data
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('エラーが発生しました: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildDeskLayout(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              setState(() {
                _isEditMode = !_isEditMode;
              });
            },
            icon: Icon(_isEditMode ? Icons.done : Icons.edit),
            label: Text(_isEditMode ? '完了' : '編集'),
            heroTag: 'editButton',
          ),
          const SizedBox(height: 16),
          if (_isEditMode)
            FloatingActionButton(
              onPressed: _addNewDesk,
              tooltip: '机を追加',
              child: const Icon(Icons.add),
              heroTag: 'addButton',
            ),
        ],
      ),
    );
  }

  Widget _buildDeskLayout() {
    // Ensure we have at least 10 desk positions (5x2 grid)
    int totalDesks = _deskAssignments.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEditMode ? '机配置を編集' : '机配置',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isEditMode)
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('デフォルト配置に戻す'),
                  onPressed: () async {
                    // Ask for confirmation
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('デフォルト配置に戻す'),
                          content: const Text('現在の机配置を削除し、5x2のデフォルト配置に戻しますか？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('リセット'),
                            ),
                          ],
                        );
                      },
                    );

                    if (result == true) {
                      try {
                        // Delete all existing desks
                        for (var desk in _deskAssignments) {
                          await _firebaseService.deleteDeskAssignment(desk.deskId);
                        }

                        // Create default layout
                        await _firebaseService.initializeDefaultDeskLayout();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('机配置をリセットしました')),
                          );
                        }

                        // Refresh data
                        await _loadData();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('エラーが発生しました: $e')),
                          );
                        }
                      }
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: totalDesks == 0
                ? _buildEmptyState()
                : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: totalDesks,
              itemBuilder: (context, index) {
                final desk = _deskAssignments[index];
                return _buildDeskItem(desk);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.grid_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            '机が設定されていません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('デフォルト配置を作成'),
            onPressed: () async {
              try {
                await _firebaseService.initializeDefaultDeskLayout();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('デフォルト机配置を作成しました')),
                  );
                }

                // Refresh data
                await _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラーが発生しました: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeskItem(DeskAssignment desk) {
    final hasUser = desk.userId.isNotEmpty;

    return GestureDetector(
      onTap: _isEditMode
          ? () => _assignUserToDesk(desk)
          : null,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: hasUser ? Colors.lightGreen.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isEditMode ? Colors.blue : Colors.grey.shade400,
                width: _isEditMode ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  hasUser ? desk.userName : '未割当',
                  style: TextStyle(
                    fontWeight: hasUser ? FontWeight.bold : FontWeight.normal,
                    color: hasUser ? Colors.black : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isEditMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '位置: ${desk.position}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isEditMode)
            Positioned(
              top: 0,
              right: 0,
              child: InkWell(
                onTap: () => _deleteDesk(desk),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: const Icon(
                    Icons.delete,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}