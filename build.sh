#!/bin/zsh
# FinderMenuExtension をビルド・署名して ~/Applications にインストールし、Finder 拡張を有効にする。
#
# 使い方:
#   ./build.sh                 # ビルド + インストール + 有効化
#   SIGN_IDENTITY="Apple Development: ..." ./build.sh   # 署名に使う証明書を指定
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="FinderMenuExtension"
EXT_NAME="FinderExtension"
EXT_ID="local.findermenuextension.FinderExtension"
MIN_MACOS="13.0"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macos${MIN_MACOS}"

BUILD_DIR="build"
APP="${BUILD_DIR}/${APP_NAME}.app"
APPEX="${APP}/Contents/PlugIns/${EXT_NAME}.appex"
INSTALL_DIR="${HOME}/Applications"
INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# 署名 ID: 指定がなければ最初の Apple Development 証明書を使う
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development/ {print $2; exit}')"
fi
if [[ -z "${SIGN_IDENTITY}" ]]; then
  echo "error: Apple Development 証明書が見つかりません（SIGN_IDENTITY で指定してください）" >&2
  exit 1
fi
echo "==> 署名 ID: ${SIGN_IDENTITY}"

echo "==> バンドルを組み立て"
rm -rf "${BUILD_DIR}"
mkdir -p "${APP}/Contents/MacOS" "${APPEX}/Contents/MacOS"
cp Resources/App-Info.plist "${APP}/Contents/Info.plist"
cp Resources/Extension-Info.plist "${APPEX}/Contents/Info.plist"

echo "==> Finder 拡張をコンパイル"
swiftc -O -swift-version 5 -target "${TARGET}" \
  -parse-as-library -application-extension \
  -module-name "${EXT_NAME}" \
  -framework Cocoa -framework FinderSync \
  -Xlinker -e -Xlinker _NSExtensionMain \
  Sources/FinderExtension/*.swift \
  -o "${APPEX}/Contents/MacOS/${EXT_NAME}"

echo "==> ホストアプリをコンパイル"
swiftc -O -swift-version 5 -target "${TARGET}" \
  -module-name "${APP_NAME}" \
  -framework Cocoa \
  Sources/App/*.swift \
  -o "${APP}/Contents/MacOS/${APP_NAME}"

echo "==> 署名（拡張 → アプリの順）"
codesign --force --timestamp=none --options runtime \
  --entitlements Resources/Extension.entitlements \
  --sign "${SIGN_IDENTITY}" "${APPEX}"
codesign --force --timestamp=none --options runtime \
  --sign "${SIGN_IDENTITY}" "${APP}"
codesign --verify --deep --strict "${APP}"

echo "==> ${INSTALL_DIR} にインストール"
pkill -x "${APP_NAME}" 2>/dev/null || true
mkdir -p "${INSTALL_DIR}"
rm -rf "${INSTALLED_APP}"
ditto "${APP}" "${INSTALLED_APP}"

# build/ 側のコピーが登録されないようにし、インストール先だけを登録する
"${LSREGISTER}" -u "${APP}" 2>/dev/null || true
"${LSREGISTER}" -f "${INSTALLED_APP}"

echo "==> Finder 拡張を登録・有効化"
pluginkit -r "${APP}/Contents/PlugIns/${EXT_NAME}.appex" 2>/dev/null || true
pluginkit -a "${INSTALLED_APP}/Contents/PlugIns/${EXT_NAME}.appex"
pluginkit -e use -i "${EXT_ID}"
pluginkit -m -v -i "${EXT_ID}"

echo "==> 完了"
