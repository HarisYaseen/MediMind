import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

html.VideoElement? _globalVideoElement;
html.MediaStream? _globalStream;

Widget buildWebCamView({
  required double width,
  required double height,
  required Function(String) onScan,
}) {
  const String viewId = 'webcam-video-view';

  final videoElement = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'cover';
  
  _globalVideoElement = videoElement;

  html.window.navigator.mediaDevices?.getUserMedia({
    'video': {
      'facingMode': 'environment',
    }
  }).then((stream) {
    _globalStream = stream;
    videoElement.srcObject = stream;
  }).catchError((err) {
    print("Error starting webcam stream: $err");
  });

  ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) => videoElement);

  return SizedBox(
    width: width,
    height: height,
    child: const HtmlElementView(viewType: viewId),
  );
}

void stopWebCam() {
  try {
    if (_globalStream != null) {
      for (var track in _globalStream!.getTracks()) {
        track.stop();
      }
      _globalStream = null;
    }
    if (_globalVideoElement != null) {
      _globalVideoElement!.srcObject = null;
      _globalVideoElement = null;
    }
  } catch (e) {
    print("Error stopping webcam stream: $e");
  }
}
