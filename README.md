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

La app se firma de forma ad hoc, sin certificado de desarrollador de Apple, y no está notarizada. Esto
significa que macOS la bloqueará la primera vez que se abra, porque el `.dmg` llega marcado como archivo
descargado (cuarentena). No se puede garantizar que no haya avisos de permisos: hay que desbloquearla una vez
con una de estas dos opciones.

1. **Desde Ajustes del Sistema (recomendada):** abre la app, deja que macOS la bloquee, ve a
   Ajustes del Sistema ▸ Privacidad y seguridad y pulsa **Abrir de todos modos** en la sección de seguridad.
2. **Desde la Terminal**, quitando la marca de cuarentena:
   ```bash
   xattr -dr com.apple.quarantine /Applications/ConectorXiaomi.app
   ```

En macOS 14 y anteriores también sirve hacer clic derecho sobre la app ▸ Abrir. En macOS 15 (Sequoia) y
posteriores ese atajo ya no salta el bloqueo y hay que usar una de las dos opciones anteriores.
Para evitar el bloqueo por completo habría que firmar con un Apple Developer ID y notarizar la app.

## Manual de usuario
El manual completo, con la instalación, la conexión del celular en modo PTP, la importación paso a paso y la
solución de problemas, está en [`docs/manual-de-usuario.html`](docs/manual-de-usuario.html). Ábrelo con
cualquier navegador.

Las imágenes del manual (`docs/img/`) las genera la propia app compilada en GitHub Actions con datos ficticios,
mediante `scripts/generar_capturas.sh`. Para regenerarlas, descarga el artefacto `ConectorXiaomi-capturas` de la
última ejecución del flujo y copia los PNG a `docs/img/`.
