import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'screens/intro_screen.dart';
import 'screens/logs_screen.dart';
import 'package:flutter/services.dart';

enum SensorStatus { on, off }

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
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onError: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const DoubleBackToClose(child: IntroScreen()),
    );
  }
}

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  @override
  void initState() {
    super.initState();
    // Navigate to DashboardPage after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LogsScreen()),
        );
      }
    });
  }

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
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ],
        ),
      ),
    );
  }
}

class DoubleBackToClose extends StatefulWidget {
  final Widget child;
  const DoubleBackToClose({super.key, required this.child});

  @override
  State<DoubleBackToClose> createState() => _DoubleBackToCloseState();
}

class _DoubleBackToCloseState extends State<DoubleBackToClose> {
  DateTime? _lastBackPressed;

  Future<bool> _handleBack() async {
    final now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: "Press back again to exit",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return false;
    }
    // Exit the app directly
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldPop = await _handleBack();
          if (shouldPop) {
            // Use SystemNavigator to exit the app from any screen
            SystemNavigator.pop();
          }
        }
      },
      child: widget.child,
    );
  }
}
