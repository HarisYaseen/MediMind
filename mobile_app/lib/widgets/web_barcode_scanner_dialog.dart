import 'package:flutter/material.dart';
import 'package:myapp/utils/colors.dart';
import 'package:myapp/widgets/camera_web_helper.dart' as camera_helper;

class WebBarcodeScannerDialog extends StatefulWidget {
  const WebBarcodeScannerDialog({super.key});

  @override
  State<WebBarcodeScannerDialog> createState() => _WebBarcodeScannerDialogState();
}

class _WebBarcodeScannerDialogState extends State<WebBarcodeScannerDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    camera_helper.stopWebCam(); // Stop webcam instantly to turn off browser camera light
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded, color: primaryColor, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Live Web Scanner',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Animated Scanner Box with Real Live Webcam Stream!
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Real live webcam stream view
                    camera_helper.buildWebCamView(
                      width: double.infinity,
                      height: double.infinity,
                      onScan: (barcode) {
                        Navigator.pop(context, barcode);
                      },
                    ),
                    
                    // Outer Scanner Frame Bracket (Top-Left)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: primaryColor, width: 4),
                            left: BorderSide(color: primaryColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    // Top-Right Bracket
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: primaryColor, width: 4),
                            right: BorderSide(color: primaryColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    // Bottom-Left Bracket
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: primaryColor, width: 4),
                            left: BorderSide(color: primaryColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    // Bottom-Right Bracket
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: primaryColor, width: 4),
                            right: BorderSide(color: primaryColor, width: 4),
                          ),
                        ),
                      ),
                    ),
                    // Animated Scanning Laser Line
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Positioned(
                          top: 24 + (_animation.value * 172),
                          left: 24,
                          right: 24,
                          child: child!,
                        );
                      },
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Informational explanation
            Text(
              'Show a high-contrast barcode to your camera. If webcam blur blocks automatic read, enter or paste the barcode number below to test:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Barcode Input Box
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Barcode Number',
                hintText: 'e.g. 8964001160212',
                prefixIcon: const Icon(Icons.pin_rounded, color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
            ),
            const SizedBox(height: 20),

            // Actions Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final val = _controller.text.trim().isEmpty ? '8964001160212' : _controller.text.trim();
                      Navigator.pop(context, val);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simulate Scan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
