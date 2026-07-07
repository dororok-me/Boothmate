// audio.js — Boothmate on Google 음성 재생 모듈 v1.0.0
// Gemini 24kHz PCM 출력을 브라우저에서 재생
let playbackContext = null;
let nextPlayTime = 0;
function ensurePlaybackContext() {
  if (!playbackContext) {
    playbackContext = new AudioContext({ sampleRate: 24000 });
    nextPlayTime = 0;
  }
  return playbackContext;
}
function playAudioChunk(base64) {
  const toggle = document.getElementById('audioToggle');
  if (!toggle || !toggle.checked) return;
  const ctx = ensurePlaybackContext();
  const binary = atob(base64);
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) bytes[i] = binary.charCodeAt(i);
  const int16 = new Int16Array(bytes.buffer);
  const float32 = new Float32Array(int16.length);
  for (let i = 0; i < int16.length; i++) float32[i] = int16[i] / 32768;
  const buffer = ctx.createBuffer(1, float32.length, 24000);
  buffer.copyToChannel(float32, 0);
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  source.connect(ctx.destination);
  const now = ctx.currentTime;
  if (nextPlayTime < now) nextPlayTime = now;
  source.start(nextPlayTime);
  nextPlayTime += buffer.duration;
}
function stopPlayback() {
  if (playbackContext) { playbackContext.close(); playbackContext = null; nextPlayTime = 0; }
}
