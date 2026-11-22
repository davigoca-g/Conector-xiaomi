#!/usr/bin/env bash
# Genera el instalador build/ConectorXiaomi.dmg (ejecutar en macOS 14+ con Xcode/Command Line Tools).
# Primero compila y empaqueta la app con build_app.sh y luego crea una imagen de disco que
# contiene la app y un acceso directo a /Applications para instalarla arrastrando.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build_app.sh

APP="build/ConectorXiaomi.app"
DMG="build/ConectorXiaomi.dmg"
STAGING="build/dmg-staging"

# Carpeta temporal con el contenido que se mostrará al abrir el .dmg.
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Conector Xiaomi" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG"

rm -rf "$STAGING"
echo "Listo: $DMG  (ábrelo y arrastra la app a Applications)"
