import 'package:flutter/material.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/medicines_screen.dart';
import 'package:myapp/screens/history_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:myapp/themes/app_theme.dart';
import 'package:myapp/widgets/nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/medicine_provider.dart';
import 'package:myapp/utils/notification_service.dart';
import 'dart:async';
import 'package:myapp/widgets/alarm_dialog.dart';
import 'package:myapp/models/medicine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MedicineProvider()..fetchMedicines()),
      ],
      child: MaterialApp(
        title: 'MediMind',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Timer? _alarmTimer;
  final Set<String> _triggeredAlarms = {};

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    MedicinesScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _startAlarmCheckTimer();
  }

  @override
  void dispose() {
    _alarmTimer?.cancel();
    super.dispose();
  }

  void _startAlarmCheckTimer() {
    // Check every 10 seconds for ultra-precise and timely alarm triggers!
    _alarmTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkAlarms();
    });
  }

  void _checkAlarms() {
    final provider = Provider.of<MedicineProvider>(context, listen: false);
    final now = DateTime.now();
    final timeOfDay = TimeOfDay.fromDateTime(now);
    final currentTimeString = timeOfDay.format(context);
    final todayKey = "${now.year}-${now.month}-${now.day}";

    for (var medicine in provider.medicines) {
      for (var scheduledTimeString in medicine.times) {
        if (scheduledTimeString.trim().toLowerCase() == currentTimeString.trim().toLowerCase()) {
          final alarmKey = "${medicine.id ?? medicine.name}_${scheduledTimeString}_$todayKey";
          
          if (!_triggeredAlarms.contains(alarmKey)) {
            _triggeredAlarms.add(alarmKey);
            _triggerAlarm(medicine, scheduledTimeString);
          }
        }
      }
    }
  }

  void _triggerAlarm(Medicine medicine, String timeString) {
    // 1. Show the beautiful pulsing overlay dialog (Works perfectly on Web + Mobile!)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlarmDialog(
        medicine: medicine,
        scheduledTime: timeString,
      ),
    );

    // 2. On Mobile, trigger standard native notification channel
    NotificationService().showNotification(
      medicine.hashCode,
      "Time for ${medicine.name}!",
      "Take your dosage: ${medicine.dosage}.",
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
