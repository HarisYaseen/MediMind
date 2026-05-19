import 'package:flutter/material.dart';

Future<TimeOfDay?> showPlatformTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  return await showDialog<TimeOfDay>(
    context: context,
    builder: (BuildContext context) {
      int selectedHour = initialTime.hour;
      int selectedMinute = initialTime.minute;
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: const Text('Select Time'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<int>(
                  value: selectedHour,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedHour = newValue;
                      });
                    }
                  },
                  items: List<DropdownMenuItem<int>>.generate(24, (int index) {
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    );
                  }),
                ),
                const Text(':'),
                DropdownButton<int>(
                  value: selectedMinute,
                  onChanged: (int? newValue) {
                    if (newValue != null) {
                      setState(() {
                        selectedMinute = newValue;
                      });
                    }
                  },
                  items: List<DropdownMenuItem<int>>.generate(60, (int index) {
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(index.toString().padLeft(2, '0')),
                    );
                  }),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop(TimeOfDay(hour: selectedHour, minute: selectedMinute));
                },
              ),
            ],
          );
        },
      );
    },
  );
}
