import 'package:flutter/material.dart';
import 'logs_screen.dart';
import '../widgets/double_back_wrapper.dart';
import '../services/supabase_service.dart';
import 'intrusion_logs_screen.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum SensorStatus { on, off }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final SupabaseService _supabaseService = SupabaseService();
  bool _systemActive = false;
  bool _intruderDetected = false;
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

  List<StreamSubscription<List<Map<String, dynamic>>>>? _sensorSubscriptions;
  StreamSubscription<List<Map<String, dynamic>>>? _intrusionSubscription;

  // Add these variables to track notifications
  DateTime? _lastNotificationTime;
  Set<String> _processedLogIds = {};

  // Add this variable to track the monitoring timer
  Timer? _monitoringTimer;

  // Add this variable to track if monitoring is active
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _initializeSystemStatus();
    _setupSystemStatusListener();
    // Start monitoring immediately and refresh states
    _setupSensorMonitoring();
    _refreshSensorStates();
  }

  @override
  void dispose() {
    _cleanupMonitoring();
    super.dispose();
  }

  void _cleanupSubscriptions() {
    if (_sensorSubscriptions != null) {
      for (var subscription in _sensorSubscriptions!) {
        subscription.cancel();
      }
    }
  }

  void _setupSensorListeners() {
    _sensorSubscriptions = _sensors.map((sensor) {
      return _supabaseService.streamSensorLogs(sensor['type']).listen((
        sensorLogs,
      ) {
        if (sensorLogs.isNotEmpty) {
          final latestLog = sensorLogs.first;
          _updateSensorState(
            sensorType: latestLog['sensor_type'],
            state: latestLog['state'],
            value: latestLog['value']?.toDouble() ?? 0.0,
          );
        }
      });
    }).toList();
  }

  void _setupSensorMonitoring() {
    if (_isMonitoring) return;

    _cleanupSubscriptions();
    _intrusionSubscription?.cancel();
    _monitoringTimer?.cancel();

    try {
      _isMonitoring = true;

      _intrusionSubscription = _supabaseService.client
          .from('sensor_logs')
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false)
          .listen(
            (data) {
              if (!mounted) {
                _cleanupMonitoring();
                return;
              }
              if (data.isEmpty) return;

              // Process all logs in the data list
              setState(() {
                for (final log in data) {
                  final sensorType = log['sensor_type'] as String;
                  final state = log['state'] as String;
                  final value = log['value']?.toDouble() ?? 0.0;
                  final logId = log['id'].toString();
                  final timestamp = DateTime.parse(log['timestamp']);

                  final sensorIndex = _sensors.indexWhere(
                    (s) => s['type'] == sensorType,
                  );
                  if (sensorIndex != -1) {
                    _sensors[sensorIndex]['state'] = state;
                    _sensors[sensorIndex]['value'] = value;

                    // Only process intrusion alerts if system is armed
                    if (_systemActive &&
                        !_processedLogIds.contains(logId) &&
                        timestamp.isAfter(_systemArmedTime ?? DateTime.now())) {
                      bool isIntrusion = _supabaseService.checkForIntrusion(
                        sensorType,
                        state,
                      );
                      if (isIntrusion) {
                        _sensors[sensorIndex]['alert'] = true;
                        _processedLogIds.add(logId);
                        _intruderDetected = true;
                        _showConsolidatedNotification([log]);
                      }
                    }
                  }
                }
              });
            },
            onError: (error) {
              print('Error in sensor monitoring: $error');
              _intrusionSubscription?.cancel();
              _intrusionSubscription = null;
              Future.delayed(
                const Duration(seconds: 1),
                _setupSensorMonitoring,
              );
            },
            cancelOnError: false,
          );
    } catch (e) {
      print('Error setting up monitoring: $e');
      _cleanupMonitoring();
      Future.delayed(const Duration(seconds: 1), _setupSensorMonitoring);
    }
  }

  void _cleanupMonitoring() {
    _isMonitoring = false;
    _intrusionSubscription?.cancel();
    _monitoringTimer?.cancel();
    _cleanupSubscriptions();
  }

  void _updateSensorState({
    required String sensorType,
    required String state,
    required double value,
  }) {
    final sensorIndex = _sensors.indexWhere(
      (sensor) => sensor['type'] == sensorType,
    );

    if (sensorIndex != -1) {
      final sensor = _sensors[sensorIndex];
      sensor['state'] = state;
      sensor['value'] = value;

      // Only check for intrusion and show alerts if system is armed
      if (_systemActive) {
        bool isIntrusion = _supabaseService.checkForIntrusion(
          sensorType,
          state,
        );
        print('Intrusion check: $isIntrusion');

        if (isIntrusion) {
          sensor['alert'] = true;
          _showNotificationForSensor(sensor, state);
        }
      }
    }
  }

  void _setupSystemStatusListener() {
    _supabaseService.streamSystemStatus().listen(
      (status) {
        if (mounted) {
          setState(() {
            _systemActive = status['is_active'] as bool;

            if (_systemActive) {
              // Set armed time and clear processed logs when system is armed
              _systemArmedTime = DateTime.now();
              _processedLogIds.clear();
            } else {
              // Reset intrusion-related states but keep sensor states
              _intruderDetected = false;
              _systemArmedTime = null;
              _processedLogIds.clear();

              // Only clear alerts but keep sensor states
              for (var sensor in _sensors) {
                sensor['alert'] = false;
              }
            }
            // Always maintain monitoring for sensor states
            _setupSensorMonitoring();
          });
        }
      },
      onError: (error) {
        print('Error in system status listener: $error');
        if (mounted) {
          _cleanupMonitoring();
        }
      },
    );
  }

  void _initializeSystemStatus() async {
    final status = await _supabaseService.getSystemStatus();
    if (mounted) {
      setState(() {
        _systemActive = status;
      });
    }
  }

  void _showNotificationForSensor(Map<String, dynamic> sensor, String state) {
    String sensorLabel = sensor['label'];
    String stateLabel = _getStateLabel(state);

    print('Showing notification for: $sensorLabel, state: $stateLabel');

    // Play alert sound
    SystemSound.play(SystemSoundType.alert);

    // Show snackbar notification
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
                  builder: (context) => const LogsScreen(autoRefresh: true),
                ),
              );
            },
          ),
        ),
      );
    }

    // Show intrusion alert dialog
    _intruderDetected = true;
    _showIntrusionAlert();
  }

  String _getStateLabel(String state) {
    switch (state.toLowerCase()) {
      case 'motion':
        return 'motion';
      case 'bright':
        return 'light';
      case 'open':
        return 'opening';
      default:
        return state;
    }
  }

  void _handleSystemStatusChange(bool value) async {
    try {
      // Add retry logic for system status update
      int retryAttempt = 0;
      const maxRetries = 3;

      Future<void> updateStatus() async {
        try {
          await _supabaseService.updateSystemStatus(value);
          setState(() {
            _systemActive = value;
            if (value) {
              print('System armed, starting monitoring');
              _systemArmedTime = DateTime.now();
              _setupSensorMonitoring();
            } else {
              print('System disarmed, cleaning up');
              _intruderDetected = false;
              _systemArmedTime = null;
              for (var sensor in _sensors) {
                sensor['alert'] = false;
              }
              _cleanupSubscriptions();
              _intrusionSubscription?.cancel();
            }
          });
        } catch (e) {
          if (retryAttempt < maxRetries) {
            retryAttempt++;
            print('Retrying system status update (attempt $retryAttempt)');
            await Future.delayed(Duration(seconds: retryAttempt));
            await updateStatus();
          } else {
            throw e; // Rethrow if max retries reached
          }
        }
      }

      await updateStatus();
    } catch (e) {
      print('Error updating system status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error. Please try again.'),
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
        // Get screen size
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 360;

        return AlertDialog(
          backgroundColor: Colors.red,
          // Make dialog width responsive
          contentPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.05,
            vertical: 20,
          ),
          // Limit maximum width
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
      _processedLogIds
          .clear(); // Clear processed logs to allow new notifications
      _lastNotificationTime = null; // Reset notification timer

      // Reset alert states only
      for (var sensor in _sensors) {
        sensor['alert'] = false;
      }
    });
  }

  // Add this new method for consolidated notifications
  void _showConsolidatedNotification(List<Map<String, dynamic>> intrusionLogs) {
    // Create a consolidated message
    final affectedSensors = intrusionLogs.map((log) {
      final sensorType = log['sensor_type'] as String;
      final sensor = _sensors.firstWhere(
        (s) => s['type'] == sensorType,
        orElse: () => {'label': 'Unknown Sensor'},
      );
      return sensor['label'];
    }).toList();

    // Play alert sound once
    SystemSound.play(SystemSoundType.alert);

    // Show single notification with all affected sensors - make it persistent
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alert: Activity detected from: ${affectedSensors.join(", ")}!',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(days: 1), // Make it persist until dismissed
          action: SnackBarAction(
            label: 'VIEW LOGS',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LogsScreen(autoRefresh: true),
                ),
              );
            },
          ),
        ),
      );
    }

    // Show intrusion alert dialog
    _showIntrusionAlert();
  }

  // Add this method to force refresh sensor states
  void _refreshSensorStates() async {
    final logs = await _supabaseService.getSensorLogs();
    if (logs.isNotEmpty) {
      for (var log in logs.take(3)) {
        _updateSensorState(
          sensorType: log['sensor_type'],
          state: log['state'],
          value: log['value']?.toDouble() ?? 0.0,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackWrapper(
      child: Scaffold(
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
                  MaterialPageRoute(builder: (context) => const LogsScreen()),
                );
              },
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
                            color: _systemActive ? Colors.green : Colors.red,
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
                      onChanged: _handleSystemStatusChange,
                      activeColor: const Color(0xFFFFD700),
                    ),
                  ),
                  if (_systemActive)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () async {
                              if (_systemActive) {
                                setState(() {
                                  _updateSensorState(
                                    sensorType: 'pir',
                                    state: 'motion',
                                    value: 1.0,
                                  );
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'System must be armed to test alerts',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'Test Alert',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            onPressed: _handleReset,
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
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
                  final bool isAlert =
                      sensor['alert'] as bool; // Explicitly cast to bool

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
