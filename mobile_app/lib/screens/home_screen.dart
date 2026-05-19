import 'package:flutter/material.dart';
import 'package:myapp/models/medicine.dart';
import 'package:myapp/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/medicine_provider.dart';
import 'package:myapp/screens/add_medicine_screen.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/widgets/web_barcode_scanner_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MedicineProvider>(context);
    final medicines = provider.medicines;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome to MediMind AI',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.1),
                    radius: 24,
                    child: const Icon(Icons.person_outline, color: primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Health Summary Card (Dashboard overview)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryColor, Color(0xFF003D5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today\'s Status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      medicines.isEmpty
                          ? 'No reminders'
                          : '${medicines.length} Active Reminders',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      medicines.isEmpty
                          ? 'Tap below to add your medicine reminders.'
                          : 'Your schedule is synced and local reminders are armed.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions Header
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),

              // Quick Actions Grid Row
              Row(
                children: [
                  // Action 1: Add Reminder
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddMedicineScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.add_alarm_rounded, color: primaryColor, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Add Reminder',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Action 2: Scan Barcode
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        String? res;
                        if (kIsWeb) {
                          res = await showDialog<String>(
                            context: context,
                            builder: (context) => const WebBarcodeScannerDialog(),
                          );
                        } else {
                          var scanRes = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SimpleBarcodeScannerPage(),
                            ),
                          );
                          if (scanRes is String && scanRes != '-1') {
                            res = scanRes;
                          }
                        }

                        if (res != null && res.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddMedicineScreen(initialBarcode: res),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, color: Colors.teal.shade700, size: 36),
                            const SizedBox(height: 12),
                            Text(
                              'Scan Barcode',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Upcoming Doses Section
              const Text(
                'Upcoming Schedule Preview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 12),

              // Schedule List View
              medicines.isEmpty
                  ? _buildEmptyState()
                  : _buildSchedulePreviewList(medicines),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        children: [
          Icon(Icons.check_circle_outline, color: Colors.grey, size: 48),
          const SizedBox(height: 12),
          Text(
            'All done for today!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulePreviewList(List<Medicine> medicines) {
    return Column(
      children: List.generate(
        medicines.length > 3 ? 3 : medicines.length, // Show up to 3 upcoming
        (index) {
          final medicine = medicines[index];
          final timeString = medicine.times.isNotEmpty ? medicine.times.first : 'No time set';
          return Card(
            margin: const EdgeInsets.only(bottom: 12.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.access_time, color: primaryColor, size: 24),
              ),
              title: Text(
                medicine.name,
                style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
              ),
              subtitle: Text('${medicine.dosage} • $timeString'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
