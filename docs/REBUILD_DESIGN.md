# Boothmate iOS 재구축 설계 문서 (v2.0 네이티브)

> 작성일: 2026-07-07 · 대상: 앱스토어 기존 앱(`com.dororok.Boothmate`, 표시명 BoothmatePro) 업데이트
> 목적: 웹앱(`dororok-me/boothmate-online-web`)의 Gemini Live 통역 서비스를 **네이티브 iOS 앱**으로 재구현.
> 기존 온디바이스 자막 앱(SFSpeechRecognizer 기반)은 폐기하고, 웹앱과 동일한 백엔드에 붙는 클라이언트로 전환한다.

---

## 0. 한 줄 요약

**무료 다운로드 → 시간권(소비형 IAP) 구매 → 실시간 전사·번역(Gemini Live, 기존 Railway 중계 서버 경유) → 잔여시간 서버 차감.** 글로서리(양방향·클라우드 동기화), 환율·도량형 환산은 전 등급 개방.

---

## 1. 왜 네이티브인가 (기존 문제 해결)

| 기존 문제 | 원인 | v2.0 해결 |
|---|---|---|
| 앱 시작 20초 | WKWebView로 무거운 원격 페이지 로딩 | 네이티브 SwiftUI, 원격 페이지 없음 |
| 리뷰 리젝 우려(4.2 웹래퍼) | 웹페이지를 앱에 로딩 | 진짜 네이티브 앱(오디오 캡처+WS+UI) |
| 결제 리젝 위험 | 토스 등 외부결제 | **StoreKit 소비형 IAP** |

> ⚠️ index.html을 WKWebView로 감싸는 것은 **금지**. 그 방식이 곧 리젝·저속의 원인.

---

## 2. 사업 모델 → 애플 규칙 매핑 (확정)

| 항목 | 웹앱 | iOS v2.0 (확정) |
|---|---|---|
| 시간권 판매 | 토스 결제 | **소비형 IAP** (5시간권/10시간권). 결제 성공 → 백엔드가 `remainingSeconds` 적립 |
| 무료 체험 | 휴대폰 번호 1회 | **DeviceCheck / App Attest** — 기기당 1회, 개인정보 미수집 |
| 로그인 | 구글 | 구글 + **Sign in with Apple**(소셜 로그인 제공 시 필수) |
| 글로서리/환율/도량형 | 전 등급 개방 | 동일(전 등급 영구 개방) — 리텐션 |
| 수수료 | — | **App Small Business Program 가입 → 15%** (연매출 $1M 미만) |

### IAP 상품 (초안 — 가격은 App Store Connect에서 확정)
- `com.dororok.Boothmate.pass.5h` — 5시간권 (Consumable)
- `com.dororok.Boothmate.pass.10h` — 10시간권 (Consumable)
- 무료 체험 **1시간**은 IAP 아님(서버가 App Attest 검증 후 기기당 1회 부여).

### 기존 구독 처리 (중요)
- App Store Connect에 자동갱신 구독 그룹 **"Boothmate Pro"(구독 1건)**가 이미 존재 → v2.0에선 제공 안 함.
- 기존 구독자 1명은 본인이 취소 전까지 계속 청구되므로 **App Store Connect에서 환불** 권장.
- **"간소화된 구입(External Purchase)"이 현재 켜짐** → 순수 IAP 규정 준수를 위해 **끄기 검토**.

> TODO: 실제 판매 금액 확정 → App Store Connect 상품 등록. 애플 최소 티어 ₩1,100부터. 선지불 API 원가 대비 15% 수수료 반영해 마진 계산.

---

## 3. 아키텍처

```
┌────────────────────────────────────────────────────────────┐
│  iOS 앱 (SwiftUI, 네이티브)                                   │
│                                                            │
│  AVAudioEngine ── 16kHz PCM16 ──┐                          │
│  (mic tap, downsample)          │                          │
│                                 ▼                          │
│  URLSessionWebSocketTask ── wss://…railway…/?ticket=…      │
│      ▲  setup / realtimeInput(audio)                       │
│      │  serverContent(input/outputTranscription,turnComplete)
│      │  boothmate(time/time_up) ← 서버가 잔여시간 푸시        │
│                                                            │
│  StoreKit 2 (소비형 IAP)  ── 영수증 ─┐                       │
│  App Attest ── attestation ─────────┤                       │
│  Firebase Auth (Apple/구글)          │                       │
└──────────────────────────────────────┼─────────────────────┘
                                        ▼
┌────────────────────────────────────────────────────────────┐
│  백엔드 (기존 Railway 중계 + 신규 훅)                          │
│  • Gemini Live 프록시 (키 서버 보관) — 있음                    │
│  • 시간 차감 / time_up 푸시 — 있음                             │
│  • [신규] IAP 영수증 검증(App Store Server API) → remainingSeconds 적립 │
│  • [신규] App Attest 검증 → 무료 1시간 1회 부여                 │
│  • [신규] iOS용 ticket 발급(유저 인증 후)                      │
│  • Firebase: users/{uid} (remainingSeconds, grade, glossaries) │
└────────────────────────────────────────────────────────────┘
```

### 보안 원칙
- **Gemini API 키는 앱에 절대 없음** (서버 전용). 유지.
- **베타 통과키(`boothmate2026secure`) 공개 앱에 절대 넣지 않음.** 공개 전 반드시 **per-user 티켓 방식**으로 전환(스펙 8장 TODO에 이미 있음).
- 티켓은 Firebase 로그인 + entitlement 확인 후 서버가 단기 발급.

---

## 4. WebSocket 프로토콜 명세 (웹 클라이언트 실제 코드 기준)

**모델**: `models/gemini-3.5-live-translate-preview`

**연결**: `wss://boothmateonline-production.up.railway.app/?ticket=<발급티켓>`

**① 연결 직후 setup 전송**
```json
{
  "setup": {
    "model": "models/gemini-3.5-live-translate-preview",
    "generationConfig": {
      "responseModalities": ["AUDIO"],
      "translationConfig": { "targetLanguageCode": "<타겟 언어코드>" }
    },
    "inputAudioTranscription": {},
    "outputAudioTranscription": {},
    "systemInstruction": { "parts": [{ "text": "<통역 지시문 + 글로서리 주입>" }] }
  }
}
```
- `systemInstruction`: 양방향 통역 지시 + 숫자 자릿수 보존 규칙 + 글로서리 용어 지시(웹의 `speechInstruction`·`glossaryInstruction` 로직 이식).

**② 오디오 스트리밍 (프레임마다)**
```json
{ "realtimeInput": { "audio": { "data": "<base64 PCM16LE>", "mimeType": "audio/pcm;rate=16000" } } }
```
- 마이크 → 16kHz 모노 다운샘플 → Int16 LE → base64.

**③ 서버 → 클라이언트 수신**
```
serverContent.inputTranscription.text   → 원문(자막 상단)
serverContent.outputTranscription.text  → 번역(자막 하단)
serverContent.modelTurn.parts[].inlineData.data → 번역 음성(TTS, 옵션 재생)
serverContent.turnComplete              → 세그먼트 종료(줄 확정)
boothmate.{type:"time", secondsLeft:N}  → 잔여시간 갱신(배지 표시)
boothmate.{type:"time_up"}              → 시간 소진 → 자동 정지 + 충전 유도
goAway                                    → 세션 곧 만료 → 재연결
```

> iOS 클라이언트는 시간 계산을 하지 않는다. **서버가 보내는 `secondsLeft`만 표시**하고 `time_up`에서 정지한다.

---

## 5. 기능 & 화면

1. **온보딩/로그인**: Sign in with Apple + 구글. 최초 App Attest → 무료 1시간 부여.
2. **메인(통역)**: 상단 원문 / 하단 번역 2단 자막 스크롤, 언어쌍·방향(자동/단방향) 선택, 시작·정지, **잔여시간 배지**, 전체보기, 폰트·테마.
3. **시간권 구매**: 5h/10h IAP, 현재 잔여시간, 구매 내역.
4. **글로서리**: 양방향 용어 추가/편집, CSV/Excel 입출력, **클라우드 동기화**(Firebase). 전 등급 개방.
5. **설정**: 언어쌍, 폰트/테마, 환율·도량형 토글, 계정, 개인정보/약관 링크.

자막 내 **환율·도량형 환산**은 번역 텍스트에 괄호로 병기(웹 `currency.js`·`unitConvert.js` 로직 이식).

---

## 6. 재사용 / 이식 / 신규

| 구성요소 | 처리 | 출처 |
|---|---|---|
| Gemini 프록시·시간차감 | **재사용(서버 그대로)** | Railway |
| WS 프로토콜 | 그대로 구현 | index.html |
| 통역 지시문·글로서리 프롬프트 | Swift 이식 | index.html `speechInstruction`/`glossaryInstruction` |
| 환율 환산 | Swift 이식 | `currency.js` |
| 도량형 환산 | Swift 이식 | `unitConvert.js` |
| 후처리 치환 | Swift 이식 | `postprocess.js` |
| 오디오 16kHz 다운샘플 | AVAudioEngine으로 재작성 | `audio.js`/`pcm-processor.js` |
| IAP 검증→적립 | **신규(백엔드)** | — |
| App Attest 검증 | **신규(백엔드)** | — |
| iOS 티켓 발급 | **신규(백엔드, 소폭)** | 스펙에 설계됨 |
| 오버레이/OBS | 스킵(후순위) | `overlay.html` |

---

## 7. 데이터 모델 (역할 분리)

- **Firebase = 로그인(Auth) 전용** — 프로젝트 `dororokrealtimespeech`. Apple/Google로 인증, ID 토큰의 `email`을 `user_id`로 사용. (Firestore/RTDB에 앱 데이터 저장 안 함)
- **Turso(relay 서버) = 실제 데이터** — 시간 잔액과 글로서리를 서버가 보관:
  - `user_balance(user_id, seconds_left)` — 잔여시간(기존)
  - `relay_ticket(...)` — 단기 티켓(기존)
  - `purchase(transaction_id, user_id, product_id, seconds, ts)` — IAP 멱등(신규)
  - `trial_device(key_id, user_id, granted_at)` — App Attest 무료 1회(신규)
  - 글로서리: 서버 `GET/PUT /glossary`(Turso, 이미 구현 v3.2.0)
- 웹의 `grade`/lock-in/토스/휴대폰 필드는 iOS에선 단순화: 글로서리 전면 개방, 결제는 IAP 소비형.

---

## 8. 앱스토어 제출 요건 & 보존 식별자

### 반드시 보존 (기존 리스팅 업데이트) — App Store Connect 실측값
- **표시명**: BoothmatePro · **Apple ID**: `6761739093` · **SKU**: `com.dororok.Boothmate`
- **Bundle ID**: `com.dororok.Boothmate` (변경 금지, 확인됨)
- **Team**: `7WHUP4PG44`
- **카테고리**: 비즈니스(주)/생산성(부) · **연령**: 4+ · **기준가 통화**: USD · **175개국**
- **현재 배포 준비 버전 `1.0.2`** → v2.0은 **`MARKETING_VERSION 2.0.0` 이상 + build 상향** (1.0.2보다 높아야 함)

### 프로젝트 정비
- **CocoaPods 제거**: Azure 팟(`MicrosoftCognitiveServicesSpeech`) 불필요 → `Podfile`/`Pods/`/`.xcworkspace` 삭제, `.xcodeproj` 직접 사용.
- **의존성**: Firebase(Auth/Firestore)는 **SwiftPM**로 추가.
- **배포 타깃**: 현재 17.6/26.2 혼재 → **iOS 16 또는 17로 통일**(26.2는 최신 기기만 되어 치명적).
- **권한**: 마이크(`NSMicrophoneUsageDescription`) 유지. **음성인식(`NSSpeechRecognitionUsageDescription`)은 제거 가능** — 이제 SFSpeechRecognizer 미사용, 오디오는 Gemini로 전송.
- **Capabilities**: In-App Purchase, Sign in with Apple, App Attest, (선택)Background Audio.

### App Store Connect / 리뷰 노트
- **App Privacy(영양성분표)**: 오디오가 Google(Gemini)로 전송됨을 명시. 개인정보/약관 URL(웹의 `privacy.html`/`terms.html` 활용).
- **IAP 상품** 2종 등록 + 심사 첨부.
- **리뷰어 데모 계정** 또는 무료 1시간으로 기능 시연 가능하게.
- **수출 규정(Export Compliance)**: HTTPS/WSS만 사용 → 표준 암호화 예외 신고.

---

## 9. 구현 로드맵 (단계별)

- **P0 디렉토리 정비**: Pods 제거, 기존 Swift 소스 제거, `.xcodeproj` 식별자 보존한 빈 네이티브 골격.
- **P1 통역 코어**: AVAudioEngine 16kHz 캡처 → WS(setup/realtimeInput) → 2단 자막 수신. (개발 중엔 베타 통과키로 로컬 검증)
- **P2 인증·티켓**: Sign in with Apple + 구글(Firebase) → 서버 티켓 발급 → 티켓 방식 연결.
- **P3 시간권 IAP**: StoreKit2 소비형 구매 → 백엔드 영수증 검증 → `remainingSeconds` 적립 → 배지/`time_up` 처리.
- **P4 무료체험**: App Attest → 서버 1시간 1회 부여.
- **P5 글로서리/환율/도량형**: 로직 이식 + Firebase 동기화.
- **P6 제출**: 프라이버시/스크린샷/버전 상향/리뷰노트 → 심사.

> 백엔드(Railway/Firebase)는 이 iOS 레포 밖. P2~P4의 서버 훅은 별도 작업 필요 — 웹 레포/서버 코드 접근이 필요하면 알려주세요.

---

## 10. 미결/확인 필요

- [ ] 5h/10h **판매 금액** 확정 → IAP 상품.
- [ ] 지원 **언어쌍** 최종 목록(웹 `getPair`/`langName` 기준).
- [ ] 번역 **음성(TTS) 재생**을 iOS에서 기본 on/off?
- [ ] **Background Audio**(화면 잠금 중 통역 지속) 필요 여부.
- [ ] 서버측 IAP 검증/티켓/App Attest 훅 — 누가/어디 레포에서 구현할지.
- [ ] App Store Connect 캡쳐(App 정보·구독/IAP·가격·서명) 공유.
```

---

## 11. 서버 확장 설계 (결정 B — iOS 독립, relay 서버가 티켓까지 발급)

> 대상 레포: `dororok-me/boothmateonline` (Node 18, `ws` + `@libsql/client`(Turso)). 기존 `server.js`에 **덧붙이는** 방식. Vercel/TransWizard 미사용.

### 인증 모델
- iOS는 **Firebase Auth**(Sign in with Apple + Google)로 로그인 → **Firebase ID 토큰(JWT)** 획득.
- 모든 서버 호출에 `Authorization: Bearer <Firebase ID 토큰>`.
- 서버는 토큰을 Google 공개키(JWKS)로 검증: `iss=https://securetoken.google.com/<projectId>`, `aud=<projectId>`. `user_id = 토큰의 email`(없으면 `sub`). → 기존 `user_balance.user_id`와 동일 체계.

### 추가 엔드포인트 (기존 http 서버에 라우팅 추가)
| 메서드/경로 | 인증 | 동작 |
|---|---|---|
| `POST /ticket` | Firebase | `seconds_left>0` 확인 → `relay_ticket`(UUID, 만료 5분, used=0) 생성 → `{ticket, secondsLeft}`. 0이면 402 `no_time`. **← Vercel 발급 대체** |
| `POST /iap/verify` | Firebase | body `{jws}` → **StoreKit2 서명거래(JWS)를 Apple 루트 인증서로 서버 검증**(키 불필요) → `productId→seconds` 매핑 → `purchase` 테이블 멱등 기록 → `user_balance += seconds` → `{secondsLeft}`. (환불회수/서버알림 필요 시 App Store Server API 추가) |
| `POST /trial/claim` | Firebase | body App Attest attestation/assertion+keyId → 검증 → `trial_device`에 keyId 없으면 **+3600초 1회** → `{secondsLeft, granted}` |

### 스키마 추가 (schema.sql)
```sql
CREATE TABLE IF NOT EXISTS purchase (
  transaction_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL, product_id TEXT NOT NULL,
  seconds INTEGER NOT NULL, ts INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);
CREATE TABLE IF NOT EXISTS trial_device (
  key_id TEXT PRIMARY KEY,           -- App Attest key id (기기당 1회)
  user_id TEXT, granted_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
);
```

### 🔒 보안 수정 (필수)
- 현재 `server.js`는 WS 연결 시 처음 보는 user에게 `initializeQuota`로 **자동 5시간** 지급 → 공개 앱에선 무한 무료. **자동 지급 제거**. 잔여 0이면 연결 거부(4002), 무료는 `POST /trial/claim`(App Attest)로만 부여.
- 공개 앱에 `RELAY_PASS_KEY` 금지 → 티켓 방식만.

### 상품 → 시간 매핑 (기본안)
- `com.dororok.Boothmate.pass.5h` → 18000초 · `com.dororok.Boothmate.pass.10h` → 36000초 · 무료체험 3600초.

### Railway 환경변수 (신규)
- **필수**: `FIREBASE_PROJECT_ID=dororokrealtimespeech`, `APPSTORE_BUNDLE_ID=com.dororok.Boothmate`, `APPLE_TEAM_ID=7WHUP4PG44`. (기존 `GEMINI_API_KEY`, `TURSO_URL` 유지)
- **선택**(환불회수/서버알림 쓸 때만): `APPSTORE_ISSUER_ID`, `APPSTORE_KEY_ID`, `APPSTORE_PRIVATE_KEY`(.p8).
- IAP 기본 검증은 App Store Server API 키 없이 **JWS 로컬 검증**(Apple 루트 인증서 번들)으로 처리 → 별도 키 발급 불필요.

### 구현 시 필요한 준비물 (값은 env로 주입 → 코드엔 비밀 없음)
- Firebase 프로젝트 **`dororokrealtimespeech`** (확인됨) — Authentication에서 **Apple·Google provider 활성화** + iOS 앱(`com.dororok.Boothmate`) 등록 → `GoogleService-Info.plist`.
- App Store Server API 키는 **불필요**(JWS 로컬 검증). 환불회수/서버알림 원할 때만 App Store Connect → 통합 → **앱 내 구입 키** 생성.
- 5h/10h 가격 확정(시간 매핑은 위 기본안).
