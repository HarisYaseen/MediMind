import 'package:flutter/material.dart';
import 'package:myapp/utils/colors.dart';
import 'package:myapp/utils/time_picker.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/medicine_provider.dart';
import 'package:myapp/models/medicine.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:myapp/models/universal_medicine.dart';
import 'package:myapp/data/universal_medicines.dart';
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

  List<UniversalMedicine> _filteredSuggestions = [];

  UniversalMedicine? _findUniversalMedicine(String query) {
    for (var med in universalMedicines) {
      if (med.barcode == query || med.name.toLowerCase() == query.toLowerCase()) {
        return med;
      }
    }
    return null;
  }

  void _populateFromQuery(String query) {
    final matched = _findUniversalMedicine(query);
    if (matched != null) {
      _medicineNameController.text = matched.name;
      _dosageController.text = matched.dosage;
      _notesController.text = matched.notes;
      _filteredSuggestions = [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-filled details for ${matched.name}!'),
          backgroundColor: primaryColor,
        ),
      );
    } else {
      _medicineNameController.text = query;
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medicine Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _medicineNameController,
              onChanged: (value) {
                // If direct barcode or name match, auto-populate instantly!
                final matched = _findUniversalMedicine(value);
                if (matched != null) {
                  _populateFromQuery(value);
                  return;
                }

                setState(() {
                  if (value.isEmpty) {
                    _filteredSuggestions = [];
                  } else {
                    _filteredSuggestions = universalMedicines
                        .where((med) =>
                            med.name.toLowerCase().contains(value.toLowerCase()) ||
                            med.barcode.contains(value))
                        .toList();
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'Enter medicine name',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: primaryColor),
                  onPressed: () async {
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
                      setState(() {
                        _populateFromQuery(res!);
                      });
                    }
                  },
                ),
              ),
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
                hintText: 'Enter dosage',
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
                hintText: 'Enter notes',
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
        ),
        if (_filteredSuggestions.isNotEmpty)
          Positioned(
            top: 88, // Positioned perfectly below the Medicine Name TextField
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _filteredSuggestions.take(4).map((med) {
                  return ListTile(
                    leading: const Icon(Icons.medication, color: primaryColor),
                    title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(med.dosage),
                    onTap: () {
                      setState(() {
                        _populateFromQuery(med.name);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
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
