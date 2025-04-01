import 'package:exit_entry_system/model/user_model.dart';
import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class EntryLogScreen extends StatefulWidget {
  const EntryLogScreen({super.key});

  @override
  EntryLogScreenState createState() => EntryLogScreenState();
}

class EntryLogScreenState extends State<EntryLogScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<EntryLogModel> _logs = [];
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _showingReport = false;
  UserModel? _selectedUser;

  // Filter options
  String? _selectedUserId;
  DateTime? _startDate;
  DateTime? _endDate;

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
      // Load users for filter dropdown
      final users = await _firebaseService.getAllUsers();

      // Load logs with active filters
      final logs = await _firebaseService.getEntryLogs(
        userId: _selectedUserId,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _users = users;
        _logs = logs;
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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Ensure endDate is not before startDate
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          // Ensure startDate is not after endDate
          if (_startDate != null && _startDate!.isAfter(_endDate!)) {
            _startDate = _endDate;
          }
        }
      });

      // Reload logs with new filters
      await _loadData();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedUserId = null;
      _startDate = null;
      _endDate = null;
      _showingReport = false;
    });

    _loadData();
  }

  void _showUserReport(UserModel user) {
    setState(() {
      _selectedUser = user;
      _selectedUserId = user.id;
      _showingReport = true;
    });
    _loadData();
  }

  void _backToLogList() {
    setState(() {
      _showingReport = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showingReport
          ? AppBar(
        title: Text('${_selectedUser?.name} のレポート'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToLogList,
        ),
      )
          : AppBar(
        title: const Text('入退室ログ'),
      ),
      body: _showingReport ? _buildUserReport() : _buildLogScreen(),
      // Refresh button
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        tooltip: '更新',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildLogScreen() {
    return Column(
      children: [
        // Filter section
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ログフィルター',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          decoration: const InputDecoration(
                            labelText: 'ユーザー',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          value: _selectedUserId,
                          hint: const Text('全てのユーザー'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('全てのユーザー'),
                            ),
                            ..._users.map((user) => DropdownMenuItem<String?>(
                              value: user.id,
                              child: Text(user.name),
                            )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedUserId = value;
                              _showingReport = false;
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'フィルターをクリア',
                        onPressed: _clearFilters,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '開始日',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              _startDate != null
                                  ? DateFormat('yyyy/MM/dd').format(_startDate!)
                                  : '指定なし',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(context, false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '終了日',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: Text(
                              _endDate != null
                                  ? DateFormat('yyyy/MM/dd').format(_endDate!)
                                  : '指定なし',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Logs list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
              ? _buildEmptyState()
              : _buildLogsList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history_toggle_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'ログがありません',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasActiveFilters()
                ? 'フィルター条件に一致するログがありません'
                : 'まだ入退室の記録がありません',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          if (_hasActiveFilters())
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.clear_all),
                label: const Text('フィルターをクリア'),
                onPressed: _clearFilters,
              ),
            ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedUserId != null || _startDate != null || _endDate != null;
  }

  Widget _buildLogsList() {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm:ss');

    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final formattedDate = dateFormat.format(log.timestamp);

        // Find the username associated with this log
        final userIndex = _users.indexWhere((user) => user.id == log.userId);
        final user = userIndex != -1 ? _users[userIndex] : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: log.isEntry ? Colors.green : Colors.red,
              child: Icon(
                log.isEntry ? Icons.login : Icons.logout,
                color: Colors.white,
              ),
            ),
            title: Text(
              log.userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formattedDate),
                if (log.note != null && log.note!.isNotEmpty)
                  Text(
                    '備考: ${log.note}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: log.isEntry ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    log.isEntry ? '入室' : '退室',
                    style: TextStyle(
                      color: log.isEntry ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (user != null)
                  IconButton(
                    icon: const Icon(Icons.analytics, color: Colors.blue),
                    tooltip: 'ユーザーレポートを表示',
                    onPressed: () => _showUserReport(user),
                  ),
              ],
            ),
            isThreeLine: false,
          ),
        );
      },
    );
  }

  Widget _buildUserReport() {
    if (_selectedUser == null) {
      return const Center(child: Text('ユーザーが選択されていません'));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              '${_selectedUser!.name} の記録が見つかりません',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('選択した期間内にログがありません'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _backToLogList,
              child: const Text('ログ一覧に戻る'),
            ),
          ],
        ),
      );
    }

    // Calculate statistics
    final stats = _calculateUserStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User information card
          _buildUserInfoCard(),
          const SizedBox(height: 16),

          // Statistics cards
          Row(
            children: [
              Expanded(child: _buildStatCard('合計滞在時間', '${stats['totalHours']}時間', Icons.access_time)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('滞在日数', '${stats['daysPresent']}日', Icons.calendar_today)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('平均滞在時間', '${stats['avgHours']}時間/日', Icons.schedule)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('入退室回数', '${stats['totalEntries']}回', Icons.repeat)),
            ],
          ),
          const SizedBox(height: 24),

          // Time spent chart
          _buildTimeSpentChart(stats['dailyData']),
          const SizedBox(height: 24),

          // Recent logs
          const Text(
            '最近のログ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildRecentLogs(),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blue.shade100,
              child: Text(
                _selectedUser!.name.substring(0, 1),
                style: TextStyle(fontSize: 24, color: Colors.blue.shade800),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedUser!.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${_selectedUser!.id}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    'QRコード: ${_selectedUser!.qrCode}',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  Text(
                    '現在の状態: ${_selectedUser!.isPresent ? '入室中' : '退室中'}',
                    style: TextStyle(
                      color: _selectedUser!.isPresent ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSpentChart(List<Map<String, dynamic>> dailyData) {
    // Sort data by date
    dailyData.sort((a, b) => a['date'].compareTo(b['date']));

    // Limit to the last 30 days for readability
    if (dailyData.length > 30) {
      dailyData = dailyData.sublist(dailyData.length - 30);
    }

    final spots = dailyData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final data = entry.value;
      return FlSpot(index, data['hours']);
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '日別滞在時間',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '期間: ${DateFormat('yyyy/MM/dd').format(dailyData.first['date'])} - ${DateFormat('yyyy/MM/dd').format(dailyData.last['date'])}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? const Center(child: Text('データがありません'))
                  : LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < dailyData.length && index % 5 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MM/dd').format(dailyData[index]['date']),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                        reservedSize: 30,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLogs() {
    final dateFormat = DateFormat('yyyy/MM/dd HH:mm');
    // Get last 5 logs
    final recentLogs = _logs.take(5).toList();

    return Column(
      children: recentLogs.map((log) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: log.isEntry ? Colors.green : Colors.red,
              radius: 16,
              child: Icon(
                log.isEntry ? Icons.login : Icons.logout,
                color: Colors.white,
                size: 16,
              ),
            ),
            title: Text(
              log.isEntry ? '入室' : '退室',
              style: TextStyle(
                color: log.isEntry ? Colors.green.shade800 : Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(dateFormat.format(log.timestamp)),
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _calculateUserStats() {
    // Filter logs for the selected user
    final userLogs = _logs.where((log) => log.userId == _selectedUserId).toList();

    // Sort logs by timestamp
    userLogs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate stats
    double totalHours = 0;
    final Set<String> uniqueDates = {};
    int totalEntries = 0;
    final List<Map<String, dynamic>> dailyData = [];

    // Process logs to pair entry and exit events
    DateTime? lastEntry;
    String lastDateKey = '';
    Map<String, double> dailyHours = {};

    for (final log in userLogs) {
      // Count unique dates
      final dateKey = DateFormat('yyyy-MM-dd').format(log.timestamp);
      uniqueDates.add(dateKey);

      // Initialize daily hours if needed
      if (!dailyHours.containsKey(dateKey)) {
        dailyHours[dateKey] = 0;
      }

      if (log.isEntry) {
        // Handle entry event
        lastEntry = log.timestamp;
        totalEntries++;
      } else if (lastEntry != null) {
        // Handle exit event if we have a corresponding entry
        final duration = log.timestamp.difference(lastEntry!);
        final hours = duration.inMinutes / 60;

        // Add hours to total and daily total
        totalHours += hours;
        dailyHours[dateKey] = (dailyHours[dateKey] ?? 0) + hours;

        // Reset lastEntry
        lastEntry = null;
      }
    }

    // Convert daily hours to chart data
    dailyHours.forEach((dateStr, hours) {
      final parts = dateStr.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      dailyData.add({
        'date': date,
        'hours': hours,
      });
    });

    // Calculate average
    final daysPresent = uniqueDates.length;
    final avgHours = daysPresent > 0 ? (totalHours / daysPresent) : 0;

    return {
      'totalHours': totalHours.toStringAsFixed(1),
      'daysPresent': daysPresent,
      'avgHours': avgHours.toStringAsFixed(1),
      'totalEntries': totalEntries,
      'dailyData': dailyData,
    };
  }
}

// EntryLogModel and UserModel are imported from the app packages and defined as follows:
/*
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

  EntryLogModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.timestamp,
    required this.isEntry,
  });

  // Create from Firestore document
  factory EntryLogModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EntryLogModel(
      id: documentId,
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isEntry: map['isEntry'] as bool? ?? true,
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'timestamp': timestamp,
      'isEntry': isEntry,
    };
  }
}
*/