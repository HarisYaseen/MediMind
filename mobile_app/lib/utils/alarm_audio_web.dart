import 'dart:js' as js;

void triggerAlarmSound() {
  try {
    js.context.callMethod('eval', ["""
      if (window.audioCtx) {
        try { window.audioCtx.close(); } catch(e) {}
      }
      window.audioCtx = new (window.AudioContext || window.webkitAudioContext)();
      window.playAlarmActive = true;
      window.alarmInterval = setInterval(function() {
        if (!window.playAlarmActive) {
          clearInterval(window.alarmInterval);
          return;
        }
        
        // First Beep
        var osc1 = window.audioCtx.createOscillator();
        var gain1 = window.audioCtx.createGain();
        osc1.connect(gain1);
        gain1.connect(window.audioCtx.destination);
        osc1.type = 'sine';
        osc1.frequency.setValueAtTime(880, window.audioCtx.currentTime); // High pitch alert
        gain1.gain.setValueAtTime(0.3, window.audioCtx.currentTime);
        gain1.gain.exponentialRampToValueAtTime(0.01, window.audioCtx.currentTime + 0.15);
        osc1.start(window.audioCtx.currentTime);
        osc1.stop(window.audioCtx.currentTime + 0.15);
        
        // Second Beep (150ms delay)
        setTimeout(function() {
          if (!window.playAlarmActive) return;
          var osc2 = window.audioCtx.createOscillator();
          var gain2 = window.audioCtx.createGain();
          osc2.connect(gain2);
          gain2.connect(window.audioCtx.destination);
          osc2.type = 'sine';
          osc2.frequency.setValueAtTime(880, window.audioCtx.currentTime);
          gain2.gain.setValueAtTime(0.3, window.audioCtx.currentTime);
          gain2.gain.exponentialRampToValueAtTime(0.01, window.audioCtx.currentTime + 0.15);
          osc2.start(window.audioCtx.currentTime);
          osc2.stop(window.audioCtx.currentTime + 0.15);
        }, 150);
        
      }, 800); // Repeat beep cycle every 800ms
    """]);
  } catch (e) {
    print('Failed to play web audio: $e');
  }
}

void triggerStopAlarmSound() {
  try {
    js.context.callMethod('eval', ["""
      window.playAlarmActive = false;
      if (window.alarmInterval) {
        clearInterval(window.alarmInterval);
      }
      if (window.audioCtx) {
        window.audioCtx.close();
      }
    """]);
  } catch (e) {
    print('Failed to stop web audio: $e');
  }
}
