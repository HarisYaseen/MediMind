import 'alarm_audio_stub.dart'
    if (dart.library.js) 'alarm_audio_web.dart';

void playAlarmSound() {
  triggerAlarmSound();
}

void stopAlarmSound() {
  triggerStopAlarmSound();
}
