import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  // System Status Operations
  Future<bool> getSystemStatus() async {
    try {
      final response = await client
          .from('system_status')
          .select('is_active')
          .single();
      return response['is_active'] as bool;
    } catch (e) {
      print('Error getting system status: $e');
      return false;
    }
  }

  Future<void> updateSystemStatus(bool isActive) async {
    try {
      await client
          .from('system_status')
          .update({'is_active': isActive})
          .eq('id', 1)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Connection timed out');
            },
          );
    } catch (e) {
      print('Supabase service error: $e');
      throw Exception('Failed to update system status');
    }
  }

  // Sensor Logs Operations
  Future<void> logSensorEvent({
    required String sensorType,
    required String state,
    required double value,
  }) async {
    try {
      // Convert local time to UTC for storage
      final now = DateTime.now().toUtc();
      await client.from('sensor_logs').insert({
        'sensor_type': sensorType,
        'state': state,
        'value': value,
        'timestamp': now.toIso8601String(),
      });
    } catch (e) {
      print('Error logging sensor event: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getSensorLogs() async {
    try {
      final response = await client
          .from('sensor_logs')
          .select()
          .order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting sensor logs: $e');
      return [];
    }
  }

  // Get logs for potential intrusions (based on state values)
  Future<List<Map<String, dynamic>>> getIntrusionLogs() async {
    try {
      final response = await client
          .from('sensor_logs')
          .select()
          .or('state.eq.bright,state.eq.motion,state.eq.open')
          .order('timestamp', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting intrusion logs: $e');
      return [];
    }
  }

  // Stream for real-time sensor updates
  Stream<List<Map<String, dynamic>>> streamSensorLogs(String sensorType) {
    return client
        .from('sensor_logs')
        .stream(primaryKey: ['id'])
        .eq('sensor_type', sensorType)
        .order('timestamp', ascending: false)
        .limit(1)
        .map((data) => data as List<Map<String, dynamic>>);
  }

  // Stream for real-time system status updates
  Stream<Map<String, dynamic>> streamSystemStatus() {
    return client
        .from('system_status')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((event) => event.first);
  }

  // Helper method to check for intrusion based on sensor state
  bool checkForIntrusion(String sensorType, String state) {
    print('Checking intrusion: type=$sensorType, state=$state'); // Debug print
    final stateLower = state.toLowerCase();
    switch (sensorType) {
      case 'photosensitive':
        return stateLower == 'bright';
      case 'pir':
        return stateLower == 'motion';
      case 'ultrasonic':
        return stateLower == 'open';
      default:
        return false;
    }
  }

  Stream<List<Map<String, dynamic>>> streamIntrusionLogs() {
    return client
        .from('sensor_logs')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(1);
  }

  Future<void> logIntrusion({
    required String sensorType,
    required String state,
    required DateTime timestamp,
  }) async {
    await client.from('sensor_logs').insert({
      'sensor_type': sensorType,
      'state': state,
      'timestamp': timestamp.toIso8601String(),
      'value': 1.0,
    });
  }
}
