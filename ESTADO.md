# Estado del proyecto (para continuar en el Mac)

Última actualización: 2026-11-21

## Objetivo
App nativa de macOS para conectar un Xiaomi por USB, leer las fotos del celular e importarlas al Mac.

## Decisiones tomadas
- Conexión: USB en modo **PTP** con ImageCaptureCore (macOS no soporta MTP).
- Stack: Swift + SwiftUI nativo, macOS 14 o posterior.
- Alcance: ver galería, importar y organizar (carpetas por fecha, detección de duplicados, borrado opcional tras verificar).
- Distribución: instalador `.dmg` con firma ad hoc (sin certificado de Apple). macOS la bloquea la primera vez y hay que
  desbloquearla desde Ajustes del Sistema ▸ Privacidad y seguridad o con `xattr -dr com.apple.quarantine`. Está documentado
  en el README y en el manual.

## Dispositivo
- Modelo **22101316UG** = Redmi Note 12 Pro+ 5G global, Android 13 (MIUI 14 sin confirmar), cámara de 200 MP.
- PTP: aviso USB "Transferir fotos (PTP)" o Opciones de desarrollador ▸ Configuración USB predeterminada.

## Hecho
- Proyecto SwiftPM en `Sources/ConectorXiaomi/` (App, DeviceManager, ContentView, PhotoItem, ImportedIndex, Captura).
- **Compila en macOS.** Se corrigió la firma del delegado `didReceiveMetadata` y el flujo de GitHub Actions termina bien.
- `scripts/build_app.sh` genera `build/ConectorXiaomi.app` y `scripts/build_dmg.sh` genera `build/ConectorXiaomi.dmg`.
- Flujo `.github/workflows/build-dmg.yml` (runner `macos-latest`; `macos-14` no está soportado en esta cuenta): compila,
  genera el `.dmg` y lo sube como artefacto `ConectorXiaomi-dmg`. También genera las capturas del manual y las sube como
  artefacto `ConectorXiaomi-capturas`; ese paso tiene `continue-on-error` para no bloquear el instalador.
- Modo de demostración (`Captura.swift`): con las variables `CONECTOR_CAPTURAS` y `CONECTOR_ESCENA` la app carga un celular y
  fotos ficticias, guarda un PNG de su ventana y se cierra. Sin esas variables no cambia nada. Por eso `PhotoItem.file` es opcional.
- Funciones añadidas (compilan en Actions, **sin probar con el celular**):
  - Vista previa de video: descarga a carpeta temporal y reproduce con AVKit.
  - «Importar solo lo nuevo» en la barra superior.
  - Copia segura con archivos `.parte`, cancelar entre archivos y reanudar; lo pendiente o fallido queda seleccionado y al
    cancelar no se borra nada del celular.
  - Barra con tamaño por copiar, espacio libre en el destino, rechazo si no cabe y tiempo restante estimado.
- Manual de usuario en `docs/manual-de-usuario.html`, con imágenes en `docs/img/`, actualizado con las funciones nuevas.
- Pre-lanzamientos en GitHub Releases con el `.dmg` adjunto: `v1.0.0-prueba` (sin las funciones nuevas) y `v1.1.0-prueba`
  (la más reciente). Pull Request #1 abierto desde la rama `ccr-a8701da9-ja6pdv` hacia `main`.

## Pendiente / riesgos
1. **Nunca se probó con el celular real.** Es lo principal. Compilar no garantiza que el delegado de ImageCaptureCore
   funcione bien. Por eso el lanzamiento está marcado como pre-lanzamiento.
2. Comprobar que el celular aparece en la barra lateral y carga miniaturas.
3. Probar importar 1 foto; verificar fecha, carpeta y duplicados.
4. Probar el borrado en el celular con una sola foto (puede no estar permitido por PTP).
   Probar también cancelar a mitad de una importación y reanudar, y desconectar el cable a propósito para ver que no queda
   ningún `.parte`.
5. Comprobar si macOS pide algún permiso extra para leer el celular o escribir en la carpeta de destino. El manual lo
   menciona como posible, pero no está verificado.
6. Probar la vista previa de video con un video real, incluido uno largo o en 4K: se descarga entero antes de reproducir.
7. Fotos de 200 MP: posible lentitud en la vista previa completa.
8. Firma con Apple Developer ID y notarización: evitaría el bloqueo de la primera apertura, cuesta USD 99 al año. No hecho.
9. Los textos de solución de problemas del manual son previsiones: corregirlos con lo que se observe en la prueba real.

## Cómo seguir
```bash
git clone https://github.com/davigoca-g/Conector-xiaomi.git
cd Conector-xiaomi && git checkout ccr-a8701da9-ja6pdv
swift run
```
Si el repositorio se clonó en un equipo Windows con varias cuentas de GitHub, para subir cambios hay que usar la cuenta
`davigoca-g` (`gh auth switch -u davigoca-g`) con el permiso `workflow` (`gh auth refresh -h github.com -s workflow`),
porque se modifican archivos de `.github/workflows/`.

Al abrir una sesión nueva, decirle a Claude que lea `ESTADO.md`.
