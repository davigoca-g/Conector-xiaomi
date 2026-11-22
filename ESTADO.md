# Estado del proyecto (para continuar en el Mac)

Última actualización: 2026-11-22

## Objetivo
App nativa de macOS para conectar un Xiaomi por USB, leer las fotos del celular e importarlas al Mac.

## Decisiones tomadas
- Conexión: USB en modo **PTP** con ImageCaptureCore (macOS no soporta MTP).
- Stack: Swift + SwiftUI nativo, macOS 14 o posterior.
- Alcance: ver galería, importar y organizar (carpetas por fecha, detección de duplicados, borrado opcional tras verificar).

## Dispositivo
- Modelo **22101316UG** = Redmi Note 12 Pro+ 5G global, Android 13 (MIUI 14 sin confirmar), cámara de 200 MP.
- PTP: aviso USB "Transferir fotos (PTP)" o Opciones de desarrollador ▸ Configuración USB predeterminada.

## Hecho
- Proyecto SwiftPM completo en `Sources/ConectorXiaomi/` (App, DeviceManager, ContentView, PhotoItem, ImportedIndex).
- `scripts/build_app.sh` genera `build/ConectorXiaomi.app`.
- Subido a GitHub, rama `ccr-a8701da9-ja6pdv`. Sin PR.

## Pendiente / riesgos
1. **Nunca se compiló** (se escribió en Linux sin Swift). Primer paso en el Mac: `swift run` y corregir errores. Sospechosos: firmas del delegado `ICCameraDeviceDelegate`, `requestDeleteFiles`, `ICDeviceTypeMask`.
2. Comprobar que el celular aparece en la barra lateral y carga miniaturas.
3. Probar importar 1 foto; verificar fecha, carpeta y duplicados.
4. Probar el borrado en el celular con una sola foto (puede no estar permitido por PTP).
5. Vista previa de videos: no implementada.
6. Fotos de 200 MP: posible lentitud en la vista previa completa.

## Cómo seguir
```bash
git clone https://github.com/davigoca-g/Conector-xiaomi.git
cd Conector-xiaomi && git checkout ccr-a8701da9-ja6pdv
swift run
```
Al abrir una sesión nueva, decirle a Claude que lea `ESTADO.md`.
