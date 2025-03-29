import 'package:flutter/material.dart';
import 'user_management_screen.dart';
import 'entry_log_screen.dart';
import 'desk_layout_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  AdminScreenState createState() => AdminScreenState();
}

class AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const UserManagementScreen(),
    const EntryLogScreen(),
    const DeskLayoutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理画面'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'ユーザー管理',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '入退室ログ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view),
            label: '机配置',
          ),
        ],
      ),
    );
  }
}