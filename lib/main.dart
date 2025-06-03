import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vkoeusxmagkkfqrfcuqo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZrb2V1c3htYWdra2ZxcmZjdXFvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDg3Mjg3NzUsImV4cCI6MjA2NDMwNDc3NX0.LTEG5xAQ4C4xayjcuwG1DZEO1DOvgAL2XQhHD7ANhik',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TresMongos',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.black,
          secondary: const Color(0xFFFFD700),
          surface: Colors.black,
          background: Colors.black,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
          onError: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const IntroPage(),
    );
  }
}

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/477016567_1254800065618621_317924523131617794_n.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'TresMongos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Created by Mongosers',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                padding: const EdgeInsets.symmetric(
                  horizontal: 45,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _selectedSensor = 'photosensitive';

  final List<Map<String, String>> _sensorTypes = [
    {'value': 'photosensitive', 'label': 'Photosensitive '},
    {'value': 'pir', 'label': 'Motion '},
    {'value': 'ultrasonic', 'label': 'Ultrasonic '},
  ];

  final List<Map<String, String>> _states = [
    {'value': 'dark', 'label': 'Dark'},
    {'value': 'bright', 'label': 'Bright'},
    {'value': 'no_motion', 'label': 'No Motion'},
    {'value': 'motion', 'label': 'Motion'},
    {'value': 'open', 'label': 'Open'},
    {'value': 'close', 'label': 'Close'},
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final response = await Supabase.instance.client
          .from('sensor_logs')
          .select()
          .eq('sensor_type', _selectedSensor)
          .order('timestamp', ascending: false)
          .limit(10);

      setState(() {
        _items = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading items: $e')));
      }
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
        return Colors.blue;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final fontSize = screenWidth * 0.04; // Responsive font size
    final padding = screenWidth * 0.04; // Responsive padding

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
              child: SingleChildScrollView(
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
                        color: const Color(0xFF2d2d2d),
                        borderRadius: BorderRadius.circular(padding * 0.75),
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
                                dropdownColor: const Color(0xFF2d2d2d),
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
                                      _loading = true;
                                    });
                                    _loadItems();
                                  }
                                },
                                items: _sensorTypes
                                    .map<DropdownMenuItem<String>>((
                                      Map<String, String> sensor,
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
                        'Recent 10 Logs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize * 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: screenWidth - (padding * 2),
                        ),
                        child: Table(
                          border: TableBorder.all(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(padding * 0.5),
                          ),
                          columnWidths: {
                            0: FixedColumnWidth(
                              screenWidth * 0.35,
                            ), // Sensor Type
                            1: FixedColumnWidth(screenWidth * 0.25), // State
                            2: FixedColumnWidth(
                              screenWidth * 0.25,
                            ), // Timestamp
                          },
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: const Color(0xFF2d2d2d),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(padding * 0.5),
                                  topRight: Radius.circular(padding * 0.5),
                                ),
                              ),
                              children: [
                                TableCell(
                                  child: Padding(
                                    padding: EdgeInsets.all(padding * 0.75),
                                    child: Text(
                                      'Sensor Type',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: fontSize,
                                      ),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: EdgeInsets.all(padding * 0.75),
                                    child: Text(
                                      'State',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: fontSize,
                                      ),
                                    ),
                                  ),
                                ),
                                TableCell(
                                  child: Padding(
                                    padding: EdgeInsets.all(padding * 0.75),
                                    child: Text(
                                      'Timestamp',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: fontSize,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            ..._items.map(
                              (item) => TableRow(
                                decoration: BoxDecoration(color: Colors.black),
                                children: [
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.all(padding * 0.75),
                                      child: Text(
                                        _sensorTypes.firstWhere(
                                          (sensor) =>
                                              sensor['value'] ==
                                              item['sensor_type'],
                                          orElse: () => {
                                            'value': '',
                                            'label': 'Unknown',
                                          },
                                        )['label']!,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen
                                              ? fontSize * 0.9
                                              : fontSize,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.all(padding * 0.75),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: fontSize * 0.8,
                                            height: fontSize * 0.8,
                                            decoration: BoxDecoration(
                                              color: getStateColor(
                                                item['state'] ?? '',
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            margin: EdgeInsets.only(
                                              right: padding * 0.5,
                                            ),
                                          ),
                                          Flexible(
                                            child: Text(
                                              _states.firstWhere(
                                                (state) =>
                                                    state['value'] ==
                                                    item['state'],
                                                orElse: () => {
                                                  'value': '',
                                                  'label': 'Unknown',
                                                },
                                              )['label']!,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isSmallScreen
                                                    ? fontSize * 0.9
                                                    : fontSize,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: EdgeInsets.all(padding * 0.75),
                                      child: Text(
                                        formatTimestamp(
                                          item['timestamp'] ?? '',
                                        ),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen
                                              ? fontSize * 0.9
                                              : fontSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
