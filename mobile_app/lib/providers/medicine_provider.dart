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
      
      // 1. Quick lookup on medical databases (OpenFDA primary, RxNorm secondary, OpenFoodFacts final fallback)
      String? resolvedName;
      if (isBarcode) {
        // Try Open FDA NDC database
        try {
          final String url = 'https://api.fda.gov/drug/ndc.json?search=package_ndc:"$cleanQuery"&limit=1';
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
          if (response.statusCode == 200) {
            final Map<String, dynamic> fdaData = json.decode(response.body);
            final List? results = fdaData['results'];
            if (results != null && results.isNotEmpty) {
              resolvedName = results[0]['brand_name'] ?? results[0]['generic_name'];
            }
          }
        } catch (e) {
          print('FDA NDC lookup skipped: $e');
        }

        // Try RxNorm if FDA missed
        if (resolvedName == null) {
          try {
            final String url = 'https://rxnav.nlm.nih.gov/REST/rxcui.json?idtype=NDC&id=$cleanQuery';
            final response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              final Map<String, dynamic> rxData = json.decode(response.body);
              final String? conceptName = rxData['idGroup']?['rxconceptProperties']?[0]?['name'];
              if (conceptName != null && conceptName.isNotEmpty) {
                resolvedName = conceptName;
              }
            }
          } catch (e) {
            print('RxNorm lookup skipped: $e');
          }
        }

        // final fallback to OpenFoodFacts EAN Database
        if (resolvedName == null) {
          try {
            final String url = 'https://world.openfoodfacts.org/api/v0/product/$cleanQuery.json';
            final response = await http.get(Uri.parse(url), headers: {
              'User-Agent': 'MediMind - MobileApp - Version 1.0'
            }).timeout(const Duration(seconds: 3));
            
            if (response.statusCode == 200) {
              final Map<String, dynamic> prodData = json.decode(response.body);
              resolvedName = prodData['product']?['product_name'];
            }
          } catch (e) {
            print('Local EAN lookup skipped: $e');
          }
        }
      }

      // 2. Build the prompt dynamically
      final String searchSubject = resolvedName != null 
          ? "barcode number $cleanQuery which maps to the medicine '$resolvedName'"
          : "query/barcode value '$cleanQuery'";

      final String prompt = '''
You are a clinical pharmacy expert and professional medical AI assistant.
A user has scanned or searched for a medication with the search subject: $searchSubject.

Please check your clinical database to identify this exact medication:
1. If this is a barcode, identify the exact brand name medicine associated with it. If the EAN database mapped it to a product name ('$resolvedName'), prioritize that exact medicine name and fetch clinical instructions for it.
2. If this is a text search, identify the exact medicine name.
3. CRITICAL: If you cannot find the barcode in your database, and there was no mapped name, you MUST return the JSON with "name" set to "Unknown Medicine (Barcode: $cleanQuery)" and "notes" set to "This barcode is not globally indexed yet. Please edit the name and add your dosage details manually." Do NOT leave the name field empty for unindexed barcode numbers. If the query is completely random junk letters, set the name to an empty string "".

Provide the details in strict JSON format containing these fields:
- "name": The official, brand, or generic name of the medicine (e.g. "Panadol", "Infacol").
- "dosage": Standard recommended patient dosage instructions.
- "notes": Important patient guidelines, what the drug is used for, safety warnings, and potential side effects.
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
