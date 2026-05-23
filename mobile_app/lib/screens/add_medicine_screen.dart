import 'package:flutter/material.dart';
import 'package:myapp/utils/colors.dart';
import 'package:myapp/utils/time_picker.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/medicine_provider.dart';
import 'package:myapp/models/medicine.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:myapp/widgets/web_barcode_scanner_dialog.dart';
class AddMedicineScreen extends StatefulWidget {
  final String? initialBarcode;
  const AddMedicineScreen({super.key, this.initialBarcode});

  @override
  _AddMedicineScreenState createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _medicineNameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  bool _showSchedule = false;

  // State for Schedule View
  String _selectedFrequency = 'Every day';
  final List<bool> _selectedDays = List.filled(7, false);
  final List<TimeOfDay> _selectedTimes = [];
  final List<String> _weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  Future<bool> _showAlignmentGuideDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: primaryColor, size: 28),
              SizedBox(width: 8),
              Text('Camera Guide', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Hold your phone over the medicine packaging and align the barcode/QR code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: primaryColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Make sure the barcode is flat, well-lit, and fits inside the camera box.',
                        style: TextStyle(color: primaryColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  icon: const Icon(Icons.videocam, color: Colors.white),
                  label: const Text('Open Camera', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ) ?? false;
  }

  void _populateFromQuery(String query) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Gemini AI is analyzing medicine...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final matched = await Provider.of<MedicineProvider>(context, listen: false)
          .lookupMedicineAI(query);
          
      Navigator.pop(context); // Close loading dialog

      if (matched != null && matched['name'] != null && matched['name'].toString().isNotEmpty) {
        setState(() {
          _medicineNameController.text = matched['name'];
          _dosageController.text = matched['dosage'] ?? '';
          _notesController.text = matched['notes'] ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI auto-filled details for ${matched['name']}!'),
            backgroundColor: primaryColor,
          ),
        );
      } else {
        setState(() {
          _medicineNameController.text = query;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gemini API could not identify this code. Please enter details manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Safe dismiss
      setState(() {
        _medicineNameController.text = query;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI search error: $e. Entering manually.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateFromQuery(widget.initialBarcode!);
      });
    }
  }

  @override
  void dispose() {
    _medicineNameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _next() {
    final text = _medicineNameController.text.trim();
    // If it looks like a barcode and dosage is empty, run the AI lookup first before proceeding to scheduling
    if (RegExp(r'^\d{8,}$').hasMatch(text) && _dosageController.text.isEmpty) {
      _populateFromQuery(text);
      return;
    }
    setState(() {
      _showSchedule = true;
    });
  }

  void _saveMedicine() async {
    final name = _medicineNameController.text.trim();
    final dosage = _dosageController.text.trim();
    if (name.isEmpty || dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and dosage are required')),
      );
      return;
    }

    final medicine = Medicine(
      name: name,
      dosage: dosage,
      notes: _notesController.text.trim(),
      frequency: _selectedFrequency,
      selectedDays: _selectedFrequency == 'Specific days of the week' ? _selectedDays : null,
      times: _selectedTimes.map((t) => t.format(context)).toList(),
    );

    await Provider.of<MedicineProvider>(context, listen: false).addMedicine(medicine);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showPlatformTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && !_selectedTimes.contains(picked)) {
      setState(() {
        _selectedTimes.add(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showSchedule ? 'Schedule' : 'Add Medicine'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _showSchedule ? _buildScheduleView() : _buildAddMedicineView(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddMedicineView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medicine Name',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _medicineNameController,
                decoration: const InputDecoration(
                  hintText: 'Enter medicine name or scan barcode',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Premium AI Search Button
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              tooltip: 'Search Medicine via Gemini AI',
              style: IconButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final query = _medicineNameController.text.trim();
                if (query.isNotEmpty) {
                  _populateFromQuery(query);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a medicine name or scan a barcode first')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            // Premium Barcode Scan Button
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              tooltip: 'Scan Barcode',
              style: IconButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                String? res;
                if (kIsWeb) {
                  res = await showDialog<String>(
                    context: context,
                    builder: (context) => const WebBarcodeScannerDialog(),
                  );
                } else {
                  // Show the alignment guide first!
                  final proceed = await _showAlignmentGuideDialog();
                  if (!proceed) return;

                  var scanRes = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SimpleBarcodeScannerPage(),
                    ),
                  );
                  if (scanRes is String) {
                    final cleanRes = scanRes.trim();
                    if (cleanRes.isNotEmpty && 
                        cleanRes != '-1' && 
                        cleanRes.toLowerCase() != 'null' && 
                        cleanRes.toLowerCase() != 'failed') {
                      res = cleanRes;
                    }
                  }
                }

                if (res != null && res.isNotEmpty) {
                  // Inform the user exactly what string was read by the camera
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Scanned code: $res'),
                      backgroundColor: primaryColor,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  _populateFromQuery(res!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scan cancelled or no clear code detected'),
                      backgroundColor: Colors.grey,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Dosage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dosageController,
          decoration: const InputDecoration(
            hintText: 'Enter dosage (AI will auto-fill)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Notes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter safety notes, uses, etc. (AI will auto-fill)',
            border: OutlineInputBorder(),
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildScheduleView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequency',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedFrequency,
          items: ['Every day', 'Specific days of the week'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() {
              _selectedFrequency = newValue!;
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        if (_selectedFrequency == 'Specific days of the week')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: _buildDaySelector(),
          ),
        const SizedBox(height: 16),
        const Text(
          'Time',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        const SizedBox(height: 8),
        _buildTimeSelector(),
        const Spacer(),
        ElevatedButton(
          onPressed: _saveMedicine,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: mintGreen,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildDaySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(_weekDays.length, (index) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDays[index] = !_selectedDays[index];
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _selectedDays[index] ? primaryColor : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _weekDays[index],
                style: TextStyle(
                  color: _selectedDays[index] ? Colors.white : primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimeSelector() {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: _selectedTimes.isEmpty
              ? const Center(child: Text('No time selected'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedTimes.length,
                  itemBuilder: (context, index) {
                    final time = _selectedTimes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Chip(
                        label: Text(time.format(context)),
                        onDeleted: () {
                          setState(() {
                            _selectedTimes.removeAt(index);
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Time'),
          onPressed: _selectTime,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryColor),
          ),
        ),
      ],
    );
  }
}
