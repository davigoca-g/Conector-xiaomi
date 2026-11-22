# Conector Xiaomi

App nativa de macOS (SwiftUI, macOS 14+) para conectar un celular Xiaomi por USB,
ver su galería e importar las fotos al Mac organizadas por fecha.

## Cómo funciona
Usa **ImageCaptureCore** (framework de Apple). macOS no soporta MTP, pero sí **PTP**, así que
el celular debe estar en modo **«Transferir fotos (PTP)»**:
1. Conecta el cable y desbloquea el celular.
2. En la notificación USB elige *Transferir fotos (PTP)*.
   Si no aparece: Ajustes ▸ Opciones de desarrollador ▸ Configuración USB predeterminada ▸ PTP.

## Funciones
- Detección automática del celular y lectura de DCIM (fotos y videos).
- Miniaturas, selección múltiple y vista previa (doble clic).
- Importación a carpeta elegida, organizada por Año/Mes, Año/Mes/Día o plana.
- Detección de duplicados (índice persistente + comparación en destino).
- Verificación de tamaño tras copiar; opción de borrar del celular solo lo verificado.

## Compilar
```bash
swift run                  # desarrollo
./scripts/build_app.sh     # genera build/ConectorXiaomi.app
```
