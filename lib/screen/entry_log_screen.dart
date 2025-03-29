import 'package:exit_entry_system/model/user_model.dart';
import 'package:exit_entry_system/service/firebase_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    });

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
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
      ),
      // Refresh button
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        tooltip: '更新',
        child: const Icon(Icons.refresh),
      ),
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

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: log.isEntry ? Colors.green : Colors.red,
              child: Icon(
                log.isEntry ? Icons.login : Icons.logout,
                color: Colors.white,
              ),
            ),
            title: Text(log.userName),
            subtitle: Text(formattedDate),
            trailing: Text(
              log.isEntry ? '入室' : '退室',
              style: TextStyle(
                color: log.isEntry ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}