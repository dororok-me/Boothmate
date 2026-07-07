#!/bin/bash
#
# sync-web.sh — 웹 버전(boothmate-online-web)의 최신 파일을 앱 번들 폴백(Boothmate/Web/)으로 복사한다.
#
# 언제 쓰나?
#   앱은 평소 원격(https://online.boothmate.co.kr)을 로드하므로 웹만 고쳐 push하면 즉시 반영된다.
#   이 스크립트는 "오프라인 폴백용 사본"을 최신으로 맞추는 용도 → 가끔(예: 앱 심사 제출 전)만 실행하면 된다.
#
# 사용법:  bash scripts/sync-web.sh
#          실행 후 Xcode에서 재빌드.

set -e

WEB_REPO="https://github.com/dororok-me/boothmate-online-web"
APP_WEB_DIR="$(cd "$(dirname "$0")/.." && pwd)/Boothmate/Web"

FILES="index.html overlay.html terms.html privacy.html audio.js pcm-processor.js postprocess.js currency.js unitConvert.js logo.png favicon.svg"

echo "▶ 웹 최신본 내려받는 중..."
TMP="$(mktemp -d)"
git clone --depth 1 "$WEB_REPO" "$TMP/web" >/dev/null 2>&1

echo "▶ 앱 번들 폴백으로 복사: $APP_WEB_DIR"
for f in $FILES; do
  if [ -f "$TMP/web/$f" ]; then
    cp "$TMP/web/$f" "$APP_WEB_DIR/"
    echo "   ✓ $f"
  else
    echo "   ⚠ $f (원본에 없음, 건너뜀)"
  fi
done

rm -rf "$TMP"

# 네이티브 로그인 브리지(__boothmateNativeLogin)가 index.html에 있는지 확인.
# 웹 소스에 넣어두면 원격/폴백 모두 자동 유지된다. 없으면 경고만 표시.
if ! grep -q "__boothmateNativeLogin" "$APP_WEB_DIR/index.html"; then
  echo ""
  echo "⚠️  경고: index.html에 네이티브 로그인 브리지(__boothmateNativeLogin)가 없습니다."
  echo "   웹 소스(boothmate-online-web)의 showGate 함수 아래에 아래 코드를 추가하고 push하세요:"
  echo "     window.__boothmateNativeLogin = function(user){"
  echo "       if(!user||!user.email) return;"
  echo "       try{localStorage.setItem('boothmate_user',JSON.stringify(user));}catch(e){}"
  echo "       showApp(user);"
  echo "     };"
fi

echo ""
echo "✅ 동기화 완료. Xcode에서 재빌드하세요 (⌘B)."
