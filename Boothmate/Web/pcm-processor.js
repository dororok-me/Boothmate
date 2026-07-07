// pcm-processor.js v3.0.0 — Boothmate on Google (dororok AI Lab)
// 환경 변경 대응: Chrome 149+ 에서 AudioContext를 16kHz로 직접 열 수 없음(에러).
//   → AudioContext는 장치 기본 레이트(예: 48000)로 열고, 이 워크릿이 16kHz로 다운샘플.
//   v2.0.0의 "84바이트 조각" 문제 수정: 입력을 내부 버퍼에 누적했다가
//   일정 분량(약 0.1초, 1600 샘플) 모이면 한 번에 16k로 변환·전송.
//
// 출력: 16kHz mono 16-bit PCM (LE). 입력 레이트는 sampleRate 전역에서 읽음.

const TARGET_RATE = 16000;
const CHUNK_OUT = 1600;   // 16k 기준 0.1초 분량 모아서 전송

class PCMProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this._acc = [];        // 다운샘플된 Float32 누적
    this._frac = 0;        // 블록 경계 보간 잔여 위치
  }

  process(inputs) {
    const input = inputs[0];
    if (!input || input.length === 0) return true;
    const ch = input[0];
    if (!ch || ch.length === 0) return true;

    const inRate = sampleRate;            // 실제 장치 레이트 (전역)
    const ratio = inRate / TARGET_RATE;   // 예: 48000/16000 = 3

    if (ratio <= 1.0) {
      // 이미 16k 이하 — 그대로 누적
      for (let i = 0; i < ch.length; i++) this._acc.push(ch[i]);
    } else {
      // 선형보간 다운샘플
      let pos = this._frac;
      while (pos < ch.length) {
        const idx = Math.floor(pos);
        const next = Math.min(idx + 1, ch.length - 1);
        const t = pos - idx;
        this._acc.push(ch[idx] * (1 - t) + ch[next] * t);
        pos += ratio;
      }
      this._frac = pos - ch.length;
      if (this._frac < 0) this._frac = 0;
    }

    // 충분히 모이면 Int16으로 묶어서 전송
    while (this._acc.length >= CHUNK_OUT) {
      const slice = this._acc.splice(0, CHUNK_OUT);
      const buf = new ArrayBuffer(slice.length * 2);
      const view = new DataView(buf);
      for (let i = 0; i < slice.length; i++) {
        let s = Math.max(-1, Math.min(1, slice[i]));
        view.setInt16(i * 2, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
      }
      this.port.postMessage(buf, [buf]);
    }
    return true;
  }
}

registerProcessor('pcm-processor', PCMProcessor);
