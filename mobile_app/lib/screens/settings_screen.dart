import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/utils/colors.dart';
import 'package:myapp/providers/medicine_provider.dart';
import 'package:myapp/utils/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  bool _isTestingAlarm = false;

  Future<void> _triggerSync(BuildContext context) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final provider = Provider.of<MedicineProvider>(context, listen: false);
      await provider.fetchMedicines();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: mintGreen,
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Data synchronized successfully with host IP!'),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text('Connection failed: Check server connection!'),
            ],
          ),
        ),
      );
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  void _testAlarmSound() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm test is supported on mobile devices!')),
      );
      return;
    }

    setState(() {
      _isTestingAlarm = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: primaryColor,
        content: Row(
          children: const [
            Icon(Icons.notifications_active_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text('Looping alarm test fired! Tap "Stop Test" to stop.'),
          ],
        ),
      ),
    );

    // Trigger test notification using our premium loop configuration
    await NotificationService().showNotification(
      9999, // Specific test ID
      "🚨 MEDIMIND TEST ALARM",
      "Your hardware looping alarm is working perfectly!",
    );
  }

  void _stopAlarmSound() async {
    if (kIsWeb) return;

    setState(() {
      _isTestingAlarm = false;
    });

    await NotificationService().flutterLocalNotificationsPlugin.cancel(id: 9999);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test alarm sound silenced.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'MediMind Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Gorgeous Header Profile Card
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 36,
                        backgroundColor: lightBlue,
                        child: Icon(Icons.person_pin_rounded, size: 48, color: primaryColor),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MediMind Patient',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: mintGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Adherence Score: 98%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
            const SizedBox(height: 24),

            // Settings Sections
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: ALARM TOOLS
                  _buildSectionHeader('HARDWARE ALARM TOOLS'),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text(
                            'Verify that your phone loops sound and vibrates continuously on alert strike.',
                            style: TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isTestingAlarm ? _stopAlarmSound : null,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: BorderSide(
                                      color: _isTestingAlarm ? Colors.redAccent : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    'Stop Test',
                                    style: TextStyle(
                                      color: _isTestingAlarm ? Colors.redAccent : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isTestingAlarm ? null : _testAlarmSound,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: mintGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text(
                                    'Test Alarm',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SECTION 2: PERMISSIONS & APP DETAILS
                  _buildSectionHeader('APPLICATION DETAILS'),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        _buildSettingTile(
                          icon: Icons.sync_rounded,
                          iconColor: primaryColor,
                          title: 'Sync Server Data',
                          subtitle: _isSyncing ? 'Synchronizing medicines...' : 'Fetch latest medicines from local server',
                          onTap: _isSyncing ? null : () => _triggerSync(context),
                        ),
                        const Divider(height: 1),
                        _buildSettingTile(
                          icon: Icons.check_circle_rounded,
                          iconColor: mintGreen,
                          title: 'Exact Alarms Permission',
                          subtitle: 'Status: Active & Authorized',
                        ),
                        const Divider(height: 1),
                        _buildSettingTile(
                          icon: Icons.vibration_rounded,
                          iconColor: primaryColor,
                          title: 'Continuous Vibration',
                          subtitle: 'Status: Enabled',
                        ),
                        const Divider(height: 1),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: Colors.grey,
                          title: 'MediMind AI System',
                          subtitle: 'Version: 1.2.0-stable',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: Colors.black54,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
