import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';
import '../utils/notification_service.dart';

class MedicineProvider with ChangeNotifier {
  List<Medicine> _medicines = [];

  List<Medicine> get medicines => _medicines;

  // Statically editable server URL or IP matching your network/cloud!
  // Set this to your Render URL (e.g., 'https://medimind-backend.onrender.com') when deployed!
  static String serverUrl = '192.168.100.4';

  // Uses the cloud server URL if configured, otherwise falls back to local dev server IPs
  String get _baseUrl {
    if (serverUrl.startsWith('http://') || serverUrl.startsWith('https://')) {
      return serverUrl;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    } else if (Platform.isAndroid) {
      return 'http://$serverUrl:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  Future<void> _scheduleAllNativeAlarms() async {
    if (kIsWeb) return;
    
    // Clear all legacy alarms and reschedule clean daily instances
    await NotificationService().flutterLocalNotificationsPlugin.cancelAll();
    
    for (var medicine in _medicines) {
      for (var scheduledTime in medicine.times) {
        final int alarmId = '${medicine.id ?? medicine.name}_$scheduledTime'.hashCode;
        
        await NotificationService().scheduleDailyMedicineAlarm(
          id: alarmId,
          title: "Time for ${medicine.name}!",
          body: "Take your dosage: ${medicine.dosage}.",
          timeString: scheduledTime,
        );
      }
    }
  }

  Future<void> fetchMedicines() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/medicines'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _medicines = data.map((json) => Medicine.fromJson(json)).toList();
        notifyListeners();
        
        // Auto-synchronize the hardware alarm timers
        await _scheduleAllNativeAlarms();
      } else {
        print('Failed to fetch medicines: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching medicines: $e');
    }
  }

  Future<void> addMedicine(Medicine medicine) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/save_medicine'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(medicine.toJson()),
      );

      if (response.statusCode == 200) {
        // After successfully adding, fetch the updated list which syncs alarms
        await fetchMedicines();
      } else {
        print('Failed to add medicine: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding medicine: $e');
    }
  }

  Future<void> deleteMedicine(String id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/delete_medicine/$id'));

      if (response.statusCode == 200) {
        _medicines.removeWhere((med) => med.id == id || med.id.toString() == id);
        notifyListeners();
        
        // Reschedule active reminders to clean deleted ones
        await _scheduleAllNativeAlarms();
      } else {
        print('Failed to delete medicine: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting medicine: $e');
    }
  }
}
