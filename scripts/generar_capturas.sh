#!/usr/bin/env bash
# Genera las imágenes del manual de usuario en build/capturas/ (ejecutar en macOS 14+ con sesión gráfica).
# Abre la app ya empaquetada en tres escenas con datos ficticios; cada una guarda un PNG de su ventana
# y se cierra sola. Requiere haber ejecutado antes scripts/build_app.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/ConectorXiaomi.app/Contents/MacOS/ConectorXiaomi"
SALIDA="$PWD/build/capturas"
rm -rf "$SALIDA"
mkdir -p "$SALIDA"

for escena in espera galeria importacion; do
  echo "Capturando escena: $escena"
  CONECTOR_CAPTURAS="$SALIDA" CONECTOR_ESCENA="$escena" "$APP"
done

ls -la "$SALIDA"
