import 'package:exit_entry_system/parts/desk_grid.dart';
import 'package:exit_entry_system/parts/digita_clock.dart';
import 'package:exit_entry_system/parts/qr_scanner.dart';
import 'package:exit_entry_system/screen/admin_screen.dart';
import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../parts/analog_clock.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTime _currentDate = DateTime.now();
  late Timer _dateTimer;

  @override
  void initState() {
    super.initState();
    _startDateTimer();
    _firebaseService.initializeFirebase();
  }

  void _startDateTimer() {
    // Update the date at midnight
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      if (now.day != _currentDate.day) {
        setState(() {
          _currentDate = now;
        });
      }
    });
  }

  @override
  void dispose() {
    _dateTimer.cancel();
    super.dispose();
  }

  Future<void> _showPasswordDialog(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    bool isPasswordIncorrect = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('管理者認証'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      errorText: isPasswordIncorrect ? 'パスワードが違います' : null,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
                TextButton(
                  onPressed: () {
                    if (passwordController.text == '4510') {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminScreen(),
                        ),
                      );
                    } else {
                      setState(() {
                        isPasswordIncorrect = true;
                      });
                    }
                  },
                  child: const Text('確認'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年MM月dd日(E)', 'ja_JP');
    final formattedDate = dateFormat.format(_currentDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('入退室管理システム'),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => _showPasswordDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Date display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            alignment: Alignment.center,
            child: Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Main content area (clock and camera)
          Expanded(
            flex: 1,
            child: Row(
              children: [
                // Left side - Clocks
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      // Analog clock
                      Expanded(
                        child: Center(
                          child: AnalogClock(),
                        ),
                      ),
                      // Digital clock
                      Expanded(
                        child: Center(
                          child: DigitalClock(),
                        ),
                      ),
                    ],
                  ),
                ),

                // Right side - QR Scanner (Camera)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const QRScanner(),
                  ),
                ),
              ],
            ),
          ),

          // Desk grid
          const Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: DeskGrid(),
            ),
          ),
        ],
      ),
    );
  }
}