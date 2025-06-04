import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class LogsScreen extends StatefulWidget {
  final bool autoRefresh;

  const LogsScreen({super.key, this.autoRefresh = false});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _selectedSensor = 'pir';
  StreamSubscription<List<Map<String, dynamic>>>? _logsSubscription;

  final List<Map<String, String>> _sensorTypes = [
    {'value': 'photosensitive', 'label': 'Photosensitive'},
    {'value': 'pir', 'label': 'Motion'},
    {'value': 'ultrasonic', 'label': 'Ultrasonic'},
  ];

  final List<Map<String, String>> _states = [
    {'value': 'dark', 'label': 'Dark'},
    {'value': 'bright', 'label': 'Bright'},
    {'value': 'no_motion', 'label': 'No Motion'},
    {'value': 'motion', 'label': 'Motion'},
    {'value': 'open', 'label': 'Open'},
    {'value': 'close', 'label': 'Close'},
    {'value': 'closed', 'label': 'Closed'},
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
    if (widget.autoRefresh) {
      _setupRealtimeUpdates();
    }
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    _logsSubscription = Supabase.instance.client
        .from('sensor_logs')
        .stream(primaryKey: ['id'])
        .eq('sensor_type', _selectedSensor)
        .order('timestamp', ascending: false)
        .limit(5)
        .listen((List<Map<String, dynamic>> data) {
          if (mounted) {
            setState(() {
              _items = data;
            });
          }
        });
  }

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _items = []; // Clear existing items before loading
    });

    try {
      final response = await Supabase.instance.client
          .from('sensor_logs')
          .select('*')
          .eq('sensor_type', _selectedSensor)
          .order('timestamp', ascending: false)
          .limit(5);

      if (response == null || response is! List) {
        setState(() {
          _items = [];
          _loading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> responseData = [];
      for (var item in response) {
        if (item is Map<String, dynamic>) {
          if (item['sensor_type'] != null &&
              item['state'] != null &&
              item['timestamp'] != null) {
            responseData.add(item);
          }
        }
      }

      setState(() {
        _items = responseData;
        _loading = false;
      });
    } catch (e, stackTrace) {
      print('Error loading data: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _items = [];
        _loading = false;
      });
    }
  }

  String formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat(
        'hh:mm:ss a',
      ).format(dateTime); // 12-hour format with AM/PM
    } catch (e) {
      return timestamp;
    }
  }

  Color getStateColor(String state) {
    switch (state.toLowerCase()) {
      case 'dark':
        return Colors.grey;
      case 'bright':
        return Colors.yellow;
      case 'no_motion':
        return Colors.green;
      case 'motion':
        return Colors.red;
      case 'open':
        return Colors.orange;
      case 'close':
      case 'closed':
        return Colors.blue;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen =
        screenWidth < 600; // Adjusted breakpoint for better responsive design
    final fontSize = isSmallScreen ? 14.0 : 16.0;
    final padding = isSmallScreen ? 12.0 : 16.0;
    final headerColor = const Color(0xFF2d2d2d);

    Widget buildTableHeader() {
      return Container(
        decoration: BoxDecoration(
          color: headerColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(padding * 0.5),
            topRight: Radius.circular(padding * 0.5),
          ),
        ),
        child: Table(
          columnWidths: {
            0: FlexColumnWidth(isSmallScreen ? 1.2 : 1.5),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(1.2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(padding * 0.5),
                  topRight: Radius.circular(padding * 0.5),
                ),
              ),
              children: [
                _buildHeaderCell('Sensor Type', fontSize, padding),
                _buildHeaderCell('State', fontSize, padding),
                _buildHeaderCell('Timestamp', fontSize, padding),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text('Sensor Logs', style: TextStyle(fontSize: fontSize * 1.1)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: padding),
                              padding: EdgeInsets.symmetric(
                                horizontal: padding,
                                vertical: padding * 0.5,
                              ),
                              decoration: BoxDecoration(
                                color: headerColor,
                                borderRadius: BorderRadius.circular(
                                  padding * 0.75,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Select Sensor: ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: fontSize,
                                    ),
                                  ),
                                  SizedBox(width: padding * 0.75),
                                  Expanded(
                                    child: Theme(
                                      data: Theme.of(context).copyWith(
                                        textTheme: TextTheme(
                                          titleMedium: TextStyle(
                                            fontSize: fontSize,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _selectedSensor,
                                        isExpanded: true,
                                        dropdownColor: headerColor,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: fontSize,
                                        ),
                                        underline: Container(
                                          height: 2,
                                          color: const Color(0xFFFFD700),
                                        ),
                                        onChanged: (String? newValue) {
                                          if (newValue != null) {
                                            setState(() {
                                              _selectedSensor = newValue;
                                            });
                                            _loadItems();
                                          }
                                        },
                                        items: _sensorTypes
                                            .map<DropdownMenuItem<String>>((
                                              sensor,
                                            ) {
                                              return DropdownMenuItem<String>(
                                                value: sensor['value'],
                                                child: Text(sensor['label']!),
                                              );
                                            })
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: padding),
                              child: Text(
                                'Recent Logs',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fontSize * 1.1,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  padding * 0.5,
                                ),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  buildTableHeader(),
                                  if (_items.isEmpty)
                                    Container(
                                      padding: EdgeInsets.all(padding * 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(
                                            padding * 0.5,
                                          ),
                                          bottomRight: Radius.circular(
                                            padding * 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'No logs available for ${_sensorTypes.firstWhere((sensor) => sensor['value'] == _selectedSensor, orElse: () => {'label': 'this sensor'})['label']}',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: fontSize,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(
                                            padding * 0.5,
                                          ),
                                          bottomRight: Radius.circular(
                                            padding * 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Table(
                                        columnWidths: {
                                          0: FlexColumnWidth(
                                            isSmallScreen ? 1.2 : 1.5,
                                          ),
                                          1: FlexColumnWidth(1.0),
                                          2: FlexColumnWidth(1.2),
                                        },
                                        children: _items
                                            .map(
                                              (item) => TableRow(
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color: Colors.white24,
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                children: [
                                                  _buildCell(
                                                    _sensorTypes.firstWhere(
                                                      (sensor) =>
                                                          sensor['value'] ==
                                                          item['sensor_type'],
                                                      orElse: () => {
                                                        'label': 'Unknown',
                                                      },
                                                    )['label']!,
                                                    fontSize,
                                                    padding,
                                                  ),
                                                  _buildStateCell(
                                                    item['state'] ?? '',
                                                    fontSize,
                                                    padding,
                                                  ),
                                                  _buildCell(
                                                    formatTimestamp(
                                                      item['timestamp'] ?? '',
                                                    ),
                                                    fontSize,
                                                    padding,
                                                  ),
                                                ],
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildHeaderCell(String text, double fontSize, double padding) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCell(String text, double fontSize, double padding) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Text(
        text,
        style: TextStyle(color: Colors.white, fontSize: fontSize),
      ),
    );
  }

  Widget _buildStateCell(String state, double fontSize, double padding) {
    String displayState = state.toLowerCase();

    // For ultrasonic sensor, ensure we show only valid states
    if (_selectedSensor == 'ultrasonic') {
      if (displayState == 'closed') {
        displayState = 'close';
      }
      // If it's a numeric value, default to showing 'close' state
      if (double.tryParse(state) != null) {
        displayState = 'close';
      }
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: fontSize * 0.8,
            height: fontSize * 0.8,
            decoration: BoxDecoration(
              color: getStateColor(displayState),
              shape: BoxShape.circle,
            ),
            margin: EdgeInsets.only(right: padding * 0.5),
          ),
          Expanded(
            child: Text(
              _states.firstWhere(
                (s) => s['value'] == displayState,
                orElse: () => {'label': displayState},
              )['label']!,
              style: TextStyle(color: Colors.white, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
