import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/utils/colors.dart';
import 'package:myapp/providers/medicine_provider.dart';
import 'package:myapp/utils/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  bool _isTestingAlarm = false;
  String _selectedRingtoneName = 'Default Alarm';
  String _selectedRingtoneUri = 'content://settings/system/alarm_alert';

  static const MethodChannel _platform = MethodChannel('com.example.myapp/ringtones');
  List<Map<String, String>> _systemRingtones = [];
  bool _isLoadingRingtones = false;

  Future<void> _fetchSystemRingtones() async {
    if (kIsWeb) return;
    setState(() {
      _isLoadingRingtones = true;
    });
    try {
      final List<dynamic> result = await _platform.invokeMethod('getRingtones');
      setState(() {
        _systemRingtones = result.map((e) {
          final map = Map<String, dynamic>.from(e);
          return {
            'title': map['title']?.toString() ?? '',
            'uri': map['uri']?.toString() ?? '',
          };
        }).toList();
      });
    } catch (e) {
      print('Failed to fetch system ringtones: $e');
    } finally {
      setState(() {
        _isLoadingRingtones = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedRingtone();
  }

  Future<void> _loadSavedRingtone() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedRingtoneUri = prefs.getString('selected_ringtone_uri') ?? 'content://settings/system/alarm_alert';
      _selectedRingtoneName = prefs.getString('selected_ringtone_name') ?? 'Default Alarm';
    });
    _fetchSystemRingtones();
  }

  Future<void> _saveRingtone(String name, String uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_ringtone_uri', uri);
    await prefs.setString('selected_ringtone_name', name);
    setState(() {
      _selectedRingtoneUri = uri;
      _selectedRingtoneName = name;
    });

    // Proactively reschedule all alarms with the new sound, so the new sound applies immediately!
    try {
      final provider = Provider.of<MedicineProvider>(context, listen: false);
      await provider.fetchMedicines();
    } catch (e) {
      print('Could not auto-reschedule alarms on ringtone change: $e');
    }
  }

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

                  // SECTION: ALARM RINGTONE
                  _buildSectionHeader('ALARM RINGTONE'),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          _buildRingtoneSelectionTile(
                            context: context,
                            title: 'Active Ringtone',
                            subtitle: _selectedRingtoneName,
                            icon: Icons.music_note_rounded,
                            iconColor: primaryColor,
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

  Widget _buildRingtoneSelectionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRingtonePickerDialog(context),
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
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showRingtonePickerDialog(BuildContext context) {
    if (_systemRingtones.isEmpty && !_isLoadingRingtones) {
      _fetchSystemRingtones();
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75, // Sleek larger modal to view ringtones comfortably
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Select Alarm Ringtone',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose any of your native system ringtones or alarms.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoadingRingtones
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                        : ListView(
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // Presets Section Header
                              const Text(
                                'QUICK SYSTEM PRESETS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black45,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildRingtoneOptionTile(
                                name: '🏥 Default Alarm Sound',
                                description: 'Loud looped device alarm alert',
                                uri: 'content://settings/system/alarm_alert',
                                icon: Icons.alarm_rounded,
                              ),
                              const Divider(height: 1),
                              _buildRingtoneOptionTile(
                                name: '📞 Default System Ringtone',
                                description: 'Your active incoming call sound',
                                uri: 'content://settings/system/ringtone',
                                icon: Icons.phone_android_rounded,
                              ),
                              const Divider(height: 1),
                              _buildRingtoneOptionTile(
                                name: '🔔 Default System Notification',
                                description: 'Standard notification ping',
                                uri: 'content://settings/system/notification_sound',
                                icon: Icons.notifications_rounded,
                              ),
                              const Divider(height: 1),
                              _buildRingtoneOptionTile(
                                name: '🔇 Silent Mode',
                                description: 'Vibrate continuously without audio',
                                uri: 'silent',
                                icon: Icons.volume_off_rounded,
                              ),
                              const SizedBox(height: 24),

                              // Dynamic Ringtones Section Header
                              if (_systemRingtones.isNotEmpty) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ALL PHONE RINGTONES (${_systemRingtones.length})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black45,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.refresh_rounded, size: 18, color: primaryColor),
                                      onPressed: () async {
                                        await _fetchSystemRingtones();
                                        setModalState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._systemRingtones.map((ringtone) {
                                  return Column(
                                    children: [
                                      _buildRingtoneOptionTile(
                                        name: ringtone['title'] ?? 'Unknown Melody',
                                        description: 'Personal device audio profile',
                                        uri: ringtone['uri'] ?? '',
                                        icon: Icons.music_note_rounded,
                                      ),
                                      const Divider(height: 1),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRingtoneOptionTile({
    required String name,
    required String description,
    required String uri,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRingtoneUri == uri;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: isSelected ? primaryColor : Colors.grey.shade600,
          size: 22,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? primaryColor : Colors.black87,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: mintGreen, size: 24)
          : null,
      onTap: () {
        Navigator.pop(context);
        _saveRingtone(name, uri);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: mintGreen,
            content: Text('Ringtone changed to: $name'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
