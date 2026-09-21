#!/usr/bin/env bash
# Gera o build macOS (Mac Catalyst) do Salvage Corps pra publicar no itch.io.
#
# Uso:
#   itch/build_mac.sh            # build + zip em itch/dist/
#   itch/build_mac.sh --upload   # idem + envia pro itch via butler
#
# Variáveis opcionais:
#   ITCH_TARGET     usuario/jogo no itch (default: itsjuniordias/salvage-corps)
#   NOTARY_PROFILE  perfil do `xcrun notarytool store-credentials` (default: salvage-notary)
#
# O build usa o flag ITCH: sem Game Center e sem push (ambos exigem App
# Store), então o modo Duelos fica oculto. Se houver um certificado
# "Developer ID Application" no keychain, o app é assinado e notarizado;
# caso contrário, sai com assinatura ad-hoc (o jogador precisa liberar em
# Ajustes > Privacidade e Segurança > "Abrir Mesmo Assim").
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ITCH_DIR="$ROOT/itch"
WORK="$ITCH_DIR/.build"
DIST="$ITCH_DIR/dist"
ITCH_TARGET="${ITCH_TARGET:-itsjuniordias/salvage-corps}"
NOTARY_PROFILE="${NOTARY_PROFILE:-salvage-notary}"
APP_NAME="Salvage Corps"

VERSION=$(grep -m1 'MARKETING_VERSION' "$ROOT/$APP_NAME.xcodeproj/project.pbxproj" | sed -E 's/.*= ([^;]+);/\1/')

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

DEV_ID=$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/' || true)

COMMON_ARGS=(
  -project "$ROOT/$APP_NAME.xcodeproj"
  -scheme "$APP_NAME"
  -configuration Release
  -destination 'generic/platform=macOS,variant=Mac Catalyst'
  -derivedDataPath "$WORK/dd"
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) ITCH"
  "CODE_SIGN_ENTITLEMENTS=itch/itch.entitlements"
)

if [[ -n "$DEV_ID" ]]; then
  echo "==> Assinando com: $DEV_ID"
  xcodebuild archive "${COMMON_ARGS[@]}" -archivePath "$WORK/$APP_NAME.xcarchive" -allowProvisioningUpdates -quiet

  cat > "$WORK/export.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
EOF
  xcodebuild -exportArchive -archivePath "$WORK/$APP_NAME.xcarchive" \
    -exportOptionsPlist "$WORK/export.plist" -exportPath "$WORK/export" -allowProvisioningUpdates
  APP="$WORK/export/$APP_NAME.app"

  echo "==> Notarizando (perfil: $NOTARY_PROFILE)"
  ditto -c -k --keepParent "$APP" "$WORK/notarize.zip"
  xcrun notarytool submit "$WORK/notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
else
  echo "==> Sem certificado Developer ID — gerando build com assinatura ad-hoc"
  xcodebuild build "${COMMON_ARGS[@]}" CODE_SIGNING_ALLOWED=NO -quiet
  APP="$WORK/dd/Build/Products/Release-maccatalyst/$APP_NAME.app"
  codesign --force --deep --sign - "$APP"
fi

ZIP="$DIST/SalvageCorps-mac-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "==> Pronto: $ZIP ($(du -h "$ZIP" | cut -f1))"

if [[ "${1:-}" == "--upload" ]]; then
  command -v butler >/dev/null || { echo "butler não encontrado — veja itch/README.md"; exit 1; }
  butler push "$ZIP" "$ITCH_TARGET:mac" --userversion "$VERSION"
fi
