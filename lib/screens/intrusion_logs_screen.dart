import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';

class IntrusionLogsScreen extends StatefulWidget {
  const IntrusionLogsScreen({super.key});

  @override
  State<IntrusionLogsScreen> createState() => _IntrusionLogsScreenState();
}

class _IntrusionLogsScreenState extends State<IntrusionLogsScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _intrusionLogs = [];
  bool _isLoading = true;

  // Add filter variables
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedSensorType = 'All';
  final List<String> _sensorTypes = [
    'All',
    'photosensitive',
    'pir',
    'ultrasonic',
  ];

  @override
  void initState() {
    super.initState();
    _loadIntrusionLogs();
  }

  Future<void> _loadIntrusionLogs() async {
    setState(() => _isLoading = true);
    final logs = await _supabaseService.getIntrusionLogs();
    setState(() {
      _intrusionLogs = _filterLogs(logs);
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _filterLogs(List<Map<String, dynamic>> logs) {
    return logs.where((log) {
      final DateTime timestamp = DateTime.parse(log['timestamp'] as String);
      bool matchesDateRange = true;
      bool matchesSensorType = true;

      // Filter by date range
      if (_startDate != null) {
        matchesDateRange = timestamp.isAfter(_startDate!);
      }
      if (_endDate != null) {
        matchesDateRange =
            matchesDateRange &&
            timestamp.isBefore(_endDate!.add(const Duration(days: 1)));
      }

      // Filter by sensor type
      if (_selectedSensorType != 'All') {
        matchesSensorType = log['sensor_type'] == _selectedSensorType;
      }

      return matchesDateRange && matchesSensorType;
    }).toList();
  }

  // Add this method to convert UTC to Manila time
  String formatTimestamp(String timestamp) {
    final utcTime = DateTime.parse(timestamp);
    final manilaTime = utcTime.add(
      const Duration(hours: 8),
    ); // UTC+8 for Manila
    return DateFormat(
      'MMM d, y h:mm:ss a',
    ).format(manilaTime); // Added AM/PM format
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Intrusion History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIntrusionLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Card(
            color: const Color(0xFF2d2d2d),
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Options',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFFFFD700),
                          ),
                          label: Text(
                            _startDate == null
                                ? 'Start Date'
                                : DateFormat('MMM d, y').format(_startDate!),
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: () => _selectDate(context, true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFFFFD700),
                          ),
                          label: Text(
                            _endDate == null
                                ? 'End Date'
                                : DateFormat('MMM d, y').format(_endDate!),
                            style: const TextStyle(color: Colors.white),
                          ),
                          onPressed: () => _selectDate(context, false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedSensorType,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2d2d2d),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedSensorType = newValue;
                          _intrusionLogs = _filterLogs(_intrusionLogs);
                        });
                      }
                    },
                    items: _sensorTypes.map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          // Logs List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFFD700),
                      ),
                    ),
                  )
                : _intrusionLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No intrusion events found for selected filters',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : ListView.builder(
                    itemCount: _intrusionLogs.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final log = _intrusionLogs[index];
                      final String formattedDate = formatTimestamp(
                        log['timestamp'] as String,
                      );

                      return Card(
                        color: Colors.red.shade900,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            _getIconForSensor(log['sensor_type'] as String),
                            color: Colors.white,
                          ),
                          title: Text(
                            '${log['sensor_type']} - ${log['state']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Text(
                            'Value: ${log['value']}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForSensor(String type) {
    switch (type) {
      case 'photosensitive':
        return Icons.light_mode;
      case 'pir':
        return Icons.motion_photos_on;
      case 'ultrasonic':
        return Icons.sensors;
      default:
        return Icons.warning_amber;
    }
  }

  // Update the date picker to use Manila timezone
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime now = DateTime.now();
    final DateTime manilaTime = now.add(const Duration(hours: 8));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: manilaTime,
      firstDate: DateTime(2024),
      lastDate: manilaTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              onPrimary: Colors.black,
              surface: Color(0xFF2d2d2d),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _intrusionLogs = _filterLogs(_intrusionLogs);
      });
    }
  }
}
