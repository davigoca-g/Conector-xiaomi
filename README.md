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
./scripts/build_dmg.sh     # genera el instalador build/ConectorXiaomi.dmg
```

## Instalador (.dmg)
Si no tienes un Mac a mano, el flujo de GitHub Actions `Construir instalador macOS`
(`.github/workflows/build-dmg.yml`) compila la app en un Mac de GitHub y deja el `.dmg`
como artefacto descargable en la pestaña Actions de cada ejecución.

La app se firma de forma ad hoc, sin certificado de desarrollador. La primera vez que la abras,
macOS puede bloquearla: haz clic derecho sobre la app ▸ Abrir ▸ Abrir, o permítela en
Ajustes del Sistema ▸ Privacidad y seguridad.
