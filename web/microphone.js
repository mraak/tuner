let _micAudioContext = null;
let _micAnalyser = null;
let _micStream = null;
let _micAnimFrame = null;

async function startMicrophoneCapture(onUpdate) {
  try {
    _micStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    _micAudioContext = new (window.AudioContext || window.webkitAudioContext)();
    _micAnalyser = _micAudioContext.createAnalyser();
    _micAnalyser.fftSize = 8192;
    _micAnalyser.smoothingTimeConstant = 0.6;
    const source = _micAudioContext.createMediaStreamSource(_micStream);
    source.connect(_micAnalyser);

    function poll() {
      const freqData = new Float32Array(_micAnalyser.frequencyBinCount);
      _micAnalyser.getFloatFrequencyData(freqData);

      // Find peak bin (skip DC component at index 0)
      let maxVal = -Infinity;
      let maxIdx = 1;
      for (let i = 1; i < freqData.length; i++) {
        if (freqData[i] > maxVal) {
          maxVal = freqData[i];
          maxIdx = i;
        }
      }

      // Parabolic interpolation for sub-bin precision
      let refined = maxIdx;
      if (maxIdx > 0 && maxIdx < freqData.length - 1) {
        const prev = freqData[maxIdx - 1];
        const next = freqData[maxIdx + 1];
        const denom = 2 * maxVal - prev - next;
        if (denom !== 0) {
          refined = maxIdx + (next - prev) / (2 * denom);
        }
      }

      const sampleRate = _micAudioContext.sampleRate;
      const freq = refined * sampleRate / _micAnalyser.fftSize;
      // Convert dB to 0-1 amplitude (dB range roughly -100 to 0)
      const amplitude = Math.max(0, Math.min(1, (maxVal + 100) / 100));

      onUpdate(freq, amplitude);
      _micAnimFrame = requestAnimationFrame(poll);
    }

    poll();
    return true;
  } catch (e) {
    console.error('Microphone capture error:', e);
    return false;
  }
}

function stopMicrophoneCapture() {
  if (_micAnimFrame !== null) {
    cancelAnimationFrame(_micAnimFrame);
    _micAnimFrame = null;
  }
  if (_micStream !== null) {
    _micStream.getTracks().forEach(t => t.stop());
    _micStream = null;
  }
  if (_micAudioContext !== null) {
    _micAudioContext.close();
    _micAudioContext = null;
  }
  _micAnalyser = null;
}
