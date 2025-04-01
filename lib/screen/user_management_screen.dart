import 'package:exit_entry_system/model/user_model.dart';
import 'package:exit_entry_system/parts/add_qrcode_scanner.dart';
import 'package:exit_entry_system/parts/qr_generator.dart';
import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  UserManagementScreenState createState() => UserManagementScreenState();
}

class UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _firebaseService.getAllUsers();
      if (!_mounted) return;

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('ユーザーデータの読み込みに失敗しました: $e');
      if (!_mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showUserEditor({UserModel? user}) {
    if (!mounted) return;

    final TextEditingController nameController = TextEditingController(
      text: user?.name ?? '',
    );
    final TextEditingController qrCodeController = TextEditingController(
      text: user?.qrCode ?? '',
    );
    final bool isEditing = user != null;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? 'ユーザーを編集' : '新規ユーザー'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    hintText: '例: 山田太郎',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: qrCodeController,
                  decoration: InputDecoration(
                    labelText: 'QRコード値',
                    hintText: '例: ABC123',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // QRコードスキャンボタン
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () async {
                            try {
                              // QRコードスキャナーを呼び出す
                              final String scannedCode = await Navigator.push(
                                dialogContext,
                                MaterialPageRoute(
                                  builder: (context) => const AddQRScannerPage(),
                                ),
                              );

                              // スキャン結果がnullでない場合、テキストフィールドに設定
                              if (scannedCode.isNotEmpty) {
                                qrCodeController.text = scannedCode;
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text('QRコードのスキャンに失敗しました: $e')),
                              );
                            }
                          },
                        ),
                        // 既存のランダム生成ボタン
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            // Generate random QR code
                            final random = Random();
                            final qrCode = List.generate(
                              8,
                                  (_) => random.nextInt(10).toString(),
                            ).join();
                            qrCodeController.text = qrCode;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                if (isEditing && user!.qrCode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.qr_code),
                      label: const Text('QRコードを表示'),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _showQRCode(user);
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final qrCode = qrCodeController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('名前を入力してください')),
                  );
                  return;
                }

                if (qrCode.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('QRコード値を入力してください')),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop();

                try {
                  if (isEditing) {
                    // Update existing user
                    final updatedUser = user!.copyWith(
                      name: name,
                      qrCode: qrCode,
                    );

                    await _firebaseService.updateUser(updatedUser);

                    if (!_mounted) return;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ユーザーを更新しました')),
                      );
                    }
                  } else {
                    // Create new user
                    final newUser = UserModel(
                      id: '',
                      name: name,
                      qrCode: qrCode,
                    );

                    await _firebaseService.createUser(newUser);

                    if (!_mounted) return;
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ユーザーを作成しました')),
                      );
                    }
                  }

                  // Refresh user list
                  if (_mounted) {
                    await _loadUsers();
                  }
                } catch (e) {
                  if (_mounted) {
                    _showErrorSnackBar('エラーが発生しました: $e');
                  }
                }
              },
              child: Text(isEditing ? '更新' : '作成'),
            ),
          ],
        );
      },
    );
  }

  void _showQRCode(UserModel user) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('${user.name}のQRコード'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QRGenerator(data: user.qrCode),
              const SizedBox(height: 16),
              Text('QRコード値: ${user.qrCode}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteUser(UserModel user) async {
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('ユーザーを削除'),
          content: Text('${user.name}を削除してもよろしいですか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      try {
        await _firebaseService.deleteUser(user.id);

        if (!_mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザーを削除しました')),
          );
        }

        // Refresh user list
        if (_mounted) {
          await _loadUsers();
        }
      } catch (e) {
        if (_mounted) {
          _showErrorSnackBar('ユーザーの削除に失敗しました: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? _buildEmptyState()
          : _buildUserList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'ユーザーがいません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '右下の + ボタンから追加できます',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('ユーザーを追加'),
            onPressed: () => _showUserEditor(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                user.name.isNotEmpty
                    ? user.name.substring(0, 1)
                    : '?',
              ),
            ),
            title: Text(user.name),
            subtitle: Text('QRコード: ${user.qrCode}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: () => _showQRCode(user),
                  tooltip: 'QRコードを表示',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showUserEditor(user: user),
                  tooltip: '編集',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDeleteUser(user),
                  tooltip: '削除',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}