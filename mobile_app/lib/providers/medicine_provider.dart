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
  // Set this to your Render or PythonAnywhere URL!
  static String serverUrl = 'https://muhammadshoaib2022.pythonanywhere.com';

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

  Future<String?> _fetchCloudApiKey() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api_key')).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['apiKey'];
      }
    } catch (e) {
      print('Failed to fetch server API key, using local fallback: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> lookupMedicineAI(String query) async {
    try {
      final String cleanQuery = query.trim();
      final bool isBarcode = RegExp(r'^\d+$').hasMatch(cleanQuery);
      
      // Fetch the live API key dynamically from the server (takes ~0.1s)
      final String? serverKey = await _fetchCloudApiKey();
      final String apiKey = (serverKey != null && serverKey.isNotEmpty)
          ? serverKey
          : 'AIzaSyDEy8q-b8UE44EMz78_bJYLNYVzRoC3j8U';
      
      // 1. Quick lookup on medical/product databases (OpenProductsFacts, OpenBeautyFacts, OpenFDA NDC label, OpenFoodFacts fallback)
      String? resolvedName;
      if (isBarcode) {
        // API 1: OpenProductsFacts (catches global consumer medicines)
        try {
          final r = await http.get(
            Uri.parse('https://world.openproductsfacts.org/api/v2/product/$cleanQuery.json'),
            headers: {'User-Agent': 'MediMind-App/1.0'},
          ).timeout(const Duration(seconds: 4));
          if (r.statusCode == 200) {
            final d = json.decode(r.body);
            if (d['status'] == 1) {
              resolvedName = d['product']?['product_name'] ?? d['product']?['generic_name'];
            }
          }
        } catch (e) {
          print('OpenProductsFacts lookup skipped: $e');
        }

        // API 2: OpenBeautyFacts (catches health/pharma products)
        if (resolvedName == null) {
          try {
            final r = await http.get(
              Uri.parse('https://world.openbeautyfacts.org/api/v2/product/$cleanQuery.json'),
              headers: {'User-Agent': 'MediMind-App/1.0'},
            ).timeout(const Duration(seconds: 4));
            if (r.statusCode == 200) {
              final d = json.decode(r.body);
              if (d['status'] == 1) {
                resolvedName = d['product']?['product_name'];
              }
            }
          } catch (e) {
            print('OpenBeautyFacts lookup skipped: $e');
          }
        }

        // API 3: OpenFDA by NDC Package code (catches imported/US label matches)
        if (resolvedName == null) {
          try {
            final r = await http.get(
              Uri.parse('https://api.fda.gov/drug/label.json?search=openfda.package_ndc:"$cleanQuery"&limit=1'),
            ).timeout(const Duration(seconds: 4));
            if (r.statusCode == 200) {
              final d = json.decode(r.body);
              final List? names = d['results']?[0]?['openfda']?['brand_name'];
              if (names != null && names.isNotEmpty) {
                resolvedName = names[0];
              }
            }
          } catch (e) {
            print('OpenFDA NDC lookup skipped: $e');
          }
        }

        // API 4: OpenFoodFacts (final fallback)
        if (resolvedName == null) {
          try {
            final r = await http.get(
              Uri.parse('https://world.openfoodfacts.org/api/v0/product/$cleanQuery.json'),
              headers: {'User-Agent': 'MediMind-App/1.0'},
            ).timeout(const Duration(seconds: 4));
            if (r.statusCode == 200) {
              final d = json.decode(r.body);
              resolvedName = d['product']?['product_name'];
            }
          } catch (e) {
            print('OpenFoodFacts lookup skipped: $e');
          }
        }
      }

      // 2. Build the prompt dynamically
      final String searchSubject = resolvedName != null 
          ? "barcode number $cleanQuery which maps to the medicine '$resolvedName'"
          : "query/barcode value '$cleanQuery'";

      final String prompt = '''
You are a clinical pharmacy expert specializing in medicines available in Pakistan.
A user has scanned or searched for a medication with the search subject: $searchSubject.

Pakistani medicines are manufactured by companies like GSK Pakistan, Searle, 
Highnoon Laboratories, Barrett Hodgson, PharmEvo, Getz Pharma, Ferozsons, 
Martin Dow, and Sanofi Pakistan.

Very common Pakistani brands: Panadol, Panadol CF, Panadol Extra, Brufen, 
Augmentin, Disprin, ORS, Flagyl, Amoxil, Risek, Nexum, Ponstan, Calpol, 
Ventolin, Septran, Ciprofloxacin, Metformin, Amlodipine, Atorvastatin.

Try hard to identify this medicine. If the barcode resolved to a product name,
use that to look up the correct clinical details.

Provide the details in strict JSON format containing these fields:
- "name": The official brand or generic name of the medicine.
- "dosage": Standard recommended patient dosage instructions.
- "notes": Important patient guidelines, what it treats, safety warnings, and potential side effects.
- "barcode": The exact barcode number "${isBarcode ? cleanQuery : ''}" (if this was a barcode scan), or empty string if input was a textual name.

Return ONLY raw, valid JSON. Do not write any markdown code block fences (do not wrap in ```json), introductory text, or explanations.
''';

      // 3. Query Google Gemini directly from the phone! (With a generous 15-second timeout!)
      final bool isGroq = apiKey.startsWith('gsk_');
      if (isGroq) {
        print('Groq key detected. Routing query through cloud server...');
        final fallbackResponse = await http.post(
          Uri.parse('$_baseUrl/lookup_medicine'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'query': cleanQuery,
            'resolved_name': resolvedName ?? ''
          }),
        ).timeout(const Duration(seconds: 15));

        if (fallbackResponse.statusCode == 200) {
          return json.decode(fallbackResponse.body) as Map<String, dynamic>;
        }
        throw 'Cloud Server Error: status ${fallbackResponse.statusCode}';
      }

      final response = await http.post(
        Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json'
          }
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> rawRes = json.decode(response.body);
        final String text = rawRes['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        if (text.isNotEmpty) {
          return json.decode(text.trim()) as Map<String, dynamic>;
        }
      } else {
        print('Direct Gemini failed with status ${response.statusCode}: ${response.body}');
        throw 'Google Gemini Error: ${response.statusCode}';
      }
      return null;
    } catch (e) {
      print('Error during AI lookup: $e');
      rethrow;
    }
  }
}
