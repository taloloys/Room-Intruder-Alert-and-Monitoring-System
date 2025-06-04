import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class DoubleBackWrapper extends StatefulWidget {
  final Widget child;
  const DoubleBackWrapper({super.key, required this.child});

  @override
  State<DoubleBackWrapper> createState() => _DoubleBackWrapperState();
}

class _DoubleBackWrapperState extends State<DoubleBackWrapper> {
  DateTime? _lastBackPressed;

  void _handleBack(bool didPop) {
    if (didPop) return;

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
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: _handleBack,
      child: widget.child,
    );
  }
}
