import 'package:flutter/material.dart';
import 'logs_screen.dart';
import '../widgets/double_back_wrapper.dart';
import 'intrusion_logs_screen.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import 'dart:async';

enum SensorStatus { on, off }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _systemActive = false;
  bool _intruderDetected = false;
  bool _loading = false;
  DateTime? _systemArmedTime;
  final List<Map<String, dynamic>> _sensors = [
    {
      'type': 'photosensitive',
      'label': 'Photosensitive Sensor',
      'state': 'dark',
      'value': 0.0,
      'alert': false,
    },
    {
      'type': 'pir',
      'label': 'Motion Sensor',
      'state': 'no_motion',
      'value': 0.0,
      'alert': false,
    },
    {
      'type': 'ultrasonic',
      'label': 'Ultrasonic Sensor',
      'state': 'close',
      'value': 0.0,
      'alert': false,
    },
  ];

  StreamSubscription<Map<String, dynamic>>? _systemStatusSubscription;
  final List<StreamSubscription<List<Map<String, dynamic>>>>
  _sensorSubscriptions = [];

  // Helper to check if a state is an alert state for a sensor type
  bool _isAlertState(String type, String state) {
    switch (type) {
      case 'photosensitive':
        return state.toLowerCase() == 'bright';
      case 'pir':
        return state.toLowerCase() == 'motion';
      case 'ultrasonic':
        return state.toLowerCase() == 'open';
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSystemStatus();

    _systemStatusSubscription = _supabaseService.streamSystemStatus().listen(
      (status) {
        if (mounted && status.containsKey('is_active')) {
          setState(() {
            _systemActive = status['is_active'] as bool;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('System status stream error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      cancelOnError: false,
    );

    for (var sensor in _sensors) {
      final type = sensor['type'] as String;
      final sub = _supabaseService
          .streamSensorLogs(type)
          .listen(
            (logs) {
              if (logs.isNotEmpty && mounted) {
                final latest = logs.first;
                setState(() {
                  final idx = _sensors.indexWhere((s) => s['type'] == type);
                  if (idx != -1) {
                    _sensors[idx]['state'] = latest['state'];
                    _sensors[idx]['value'] = latest['value']?.toDouble() ?? 0.0;
                    // Alert logic
                    if (_systemActive && _isAlertState(type, latest['state'])) {
                      if (!_sensors[idx]['alert']) {
                        _sensors[idx]['alert'] = true;
                        _showNotificationForSensor(
                          _sensors[idx],
                          latest['state'],
                        );
                      }
                    } else {
                      _sensors[idx]['alert'] = false;
                    }
                  }
                });
              }
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sensor $type stream error: $error'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            cancelOnError: false,
          );
      _sensorSubscriptions.add(sub);
    }
  }

  void _showNotificationForSensor(Map<String, dynamic> sensor, String state) {
    String sensorLabel = sensor['label'];
    String stateLabel = state;
    SystemSound.play(SystemSoundType.alert);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alert: $sensorLabel detected $stateLabel!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'VIEW LOGS',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const IntrusionLogsScreen(autoRefresh: true),
                ),
              );
            },
          ),
        ),
      );
    }
    _intruderDetected = true;
    _showIntrusionAlert();
  }

  @override
  void dispose() {
    _systemStatusSubscription?.cancel();
    for (final sub in _sensorSubscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _fetchSystemStatus() async {
    setState(() => _loading = true);
    final status = await _supabaseService.getSystemStatus();
    if (mounted) {
      setState(() {
        _systemActive = status;
        _loading = false;
      });
    }
  }

  void _handleSystemStatusChange(bool value) async {
    setState(() => _loading = true);
    try {
      await _supabaseService.updateSystemStatus(value);
      setState(() {
        _systemActive = value;
        if (value) {
          _systemArmedTime = DateTime.now();
        } else {
          _intruderDetected = false;
          _systemArmedTime = null;
          for (var sensor in _sensors) {
            sensor['alert'] = false;
          }
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update system status.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showIntrusionAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 360;

        return AlertDialog(
          backgroundColor: Colors.red,
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: 20,
          ),
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.1,
            vertical: screenSize.height * 0.2,
          ),
          title: Wrap(
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 30,
              ),
              Text(
                'INTRUSION\nDETECTED!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 20,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              'Suspicious activity detected by sensors!',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
          actions: [
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Acknowledge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleReset() {
    setState(() {
      _intruderDetected = false;
      for (var sensor in _sensors) {
        sensor['alert'] = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackWrapper(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              title: const Text('Security System'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.warning_amber),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const IntrusionLogsScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LogsScreen(),
                      ),
                    );
                  },
                ),
                if (_intruderDetected)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reset',
                    onPressed: _handleReset,
                  ),
              ],
            ),
            body: Column(
              children: [
                // System Status Card
                Card(
                  color: const Color(0xFF2d2d2d),
                  margin: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'System Status',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _systemActive ? 'ARMED' : 'DISARMED',
                              style: TextStyle(
                                color: _systemActive
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_intruderDetected && _systemActive)
                              const Text(
                                'INTRUSION DETECTED!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: Switch(
                          value: _systemActive,
                          onChanged: _loading
                              ? null
                              : _handleSystemStatusChange,
                          activeColor: const Color(0xFFFFD700),
                        ),
                      ),
                    ],
                  ),
                ),
                // Sensor States
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _sensors.length,
                    itemBuilder: (context, index) {
                      final sensor = _sensors[index];
                      final bool isAlert = sensor['alert'] as bool;

                      return Card(
                        color: isAlert
                            ? Colors.red.shade900
                            : const Color(0xFF2d2d2d),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            _getIconForSensor(sensor['type']),
                            color: _systemActive
                                ? (isAlert ? Colors.red : Colors.green)
                                : Colors.grey,
                          ),
                          title: Text(
                            sensor['label'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'State: ${sensor['state']}',
                            style: TextStyle(
                              color: isAlert
                                  ? Colors.red
                                  : _getStateColor(sensor['state']),
                              fontWeight: isAlert
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
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
        return Icons.device_unknown;
    }
  }

  Color _getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'dark':
        return Colors.grey;
      case 'bright':
        return Colors.yellow;
      case 'no_motion':
        return Colors.grey;
      case 'motion':
        return Colors.green;
      case 'open':
        return Colors.green;
      case 'close':
        return Colors.grey;
      default:
        return Colors.white;
    }
  }
}
