import 'package:flutter/material.dart';

class Medicine {
  final String? id;
  final String name;
  final String dosage;
  final String? notes;
  final String frequency;
  final List<bool>? selectedDays;
  final List<String> times;

  Medicine({
    this.id,
    required this.name,
    required this.dosage,
    this.notes,
    required this.frequency,
    this.selectedDays,
    required this.times,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id']?.toString(),
      name: json['name'] ?? json['medicineName'] ?? '',
      dosage: json['dosage'] ?? '',
      notes: json['notes'],
      frequency: json['frequency'] ?? 'Every day',
      selectedDays: json['selectedDays'] != null 
          ? List<bool>.from(json['selectedDays']) 
          : null,
      times: json['times'] != null 
          ? List<String>.from(json['times']) 
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'medicineName': name, // Included for compatibility with both server.py and main.py
      'dosage': dosage,
      'notes': notes,
      'frequency': frequency,
      'selectedDays': selectedDays,
      'times': times,
    };
  }
}
