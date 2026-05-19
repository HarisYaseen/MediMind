import 'package:flutter/material.dart';

Widget buildWebCamView({
  required double width,
  required double height,
  required Function(String) onScan,
}) {
  return const Center(child: Text('Webcam not supported on this platform'));
}

void stopWebCam() {}
