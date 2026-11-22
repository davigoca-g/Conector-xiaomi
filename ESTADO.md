# Estado del proyecto (para continuar en el Mac)

Última actualización: 2026-11-22 (versión 1.2.2, estable)

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
- Funciones añadidas (compilan en Actions; ver la sección «Probado con el celular real» para lo ya verificado):
  - Vista previa de video: descarga a carpeta temporal y reproduce con AVKit.
  - «Importar solo lo nuevo» en la barra superior.
  - Copia segura con archivos `.parte`, cancelar entre archivos y reanudar; lo pendiente o fallido queda seleccionado y al
    cancelar no se borra nada del celular.
  - Barra con tamaño por copiar, espacio libre en el destino, rechazo si no cabe y tiempo restante estimado.
- Selección por lotes (menú «Seleccionar por lote» de la barra superior): todo, último mes, últimos 3 meses, último semestre,
  último año, cada año que tenga fotos y un rango de fechas libre. Por defecto omite lo ya importado (se puede desactivar).
  Pensado para pasar unas 24.000 fotos en tandas. Probada con el celular real en la 1.2.2.
- Vista de lista sin miniaturas como modo por defecto (selector «Lista / Miniaturas» en la barra superior): no se pide ninguna
  miniatura al celular, y la vista previa, desde el ojo o con doble clic, avisa que puede demorar y solo descarga al confirmar.
  En modo miniaturas la vista previa carga de inmediato como antes. Probada con el celular real en la 1.2.2.
- Corrección de la vista previa (la primera prueba real nunca cargaba): la imagen se decodifica antes de borrar el archivo
  temporal, se reduce a 2400 px, y la ventana muestra la miniatura mientras baja el archivo completo, con un mensaje claro si
  falla. Causas probables aún sin confirmar: lectura perezosa de `NSImage(contentsOf:)` o descarga en cola detrás de las miniaturas.
- Manual de usuario en `docs/manual-de-usuario.html`, con imágenes en `docs/img/`, actualizado con las funciones nuevas.
- Pre-lanzamientos en GitHub Releases con el `.dmg` adjunto: `v1.0.0-prueba` (sin las funciones nuevas), `v1.1.0-prueba` y
  `v1.2.0-prueba` y `v1.2.1-prueba`, y la versión estable `v1.2.2` (la más reciente, la que debe usarse; incluye la lista, la selección por
  lotes, la corrección de la vista previa, el ancho mínimo de 1150 px y la corrección del cierre inesperado). El Pull Request #1 ya está fusionado en `main` (la rama `ccr-a8701da9-ja6pdv` se conservó, pero
  el trabajo continúa en `main`).
- El manual y las capturas de `docs/img/` se regeneraron con la versión 1.2.1. El ancho mínimo de la ventana (`App.swift`)
  subió de 900 a 1150 px para que toda la barra superior (incluido «Seleccionar por lote» y el selector de vista) se vea
  sin plegarse bajo «>>».

## Probado con el celular real
La versión **1.2.2-prueba** se probó con el Xiaomi real y el usuario confirmó que funciona: conexión y lectura de la galería,
vista de lista, selección por lotes, importación masiva (unas 24.000 fotos en tandas) y vista previa. El cierre inesperado
que ocurría en la 1.2.1 al iniciar una importación masiva quedó resuelto: la causa era la carrera de datos en
`ImportedIndex` (el hilo de importación escribía el conjunto mientras la interfaz lo leía) y la reescritura del JSON tras
cada foto. No se llegó a revisar el informe del fallo de macOS; la corrección se dio por buena porque el problema no volvió.

## Pendiente / riesgos
1. La 1.2.2 se promovió a versión estable (release `v1.2.2`, con el mismo `.dmg` que tuvo `v1.2.2-prueba`, ya borrado). Las notas avisan de lo que aún no se ha comprobado (puntos siguientes).
2. Sin reporte explícito: verificar la fecha conservada, las carpetas y la detección de duplicados en lo ya importado.
3. Probar el borrado en el celular con una sola foto (puede no estar permitido por PTP).
   Probar también cancelar a mitad de una importación y reanudar, y desconectar el cable a propósito para ver que no queda
   ningún `.parte`.
4. Comprobar si macOS pide algún permiso extra para leer el celular o escribir en la carpeta de destino. El manual lo
   menciona como posible, pero no está verificado.
5. Probar la vista previa de video con un video real, incluido uno largo o en 4K: se descarga entero antes de reproducir.
6. Fotos de 200 MP: posible lentitud en la vista previa completa (no se reportó, pero tampoco se confirmó).
7. Firma con Apple Developer ID y notarización: evitaría el bloqueo de la primera apertura, cuesta USD 99 al año. No hecho.
8. Los textos de solución de problemas del manual son previsiones: corregirlos con lo que se observe en la prueba real.

## Cómo seguir
```bash
git clone https://github.com/davigoca-g/Conector-xiaomi.git
cd Conector-xiaomi
swift run
```
Si el repositorio se clonó en un equipo Windows con varias cuentas de GitHub, para subir cambios hay que usar la cuenta
`davigoca-g` (`gh auth switch -u davigoca-g`) con el permiso `workflow` (`gh auth refresh -h github.com -s workflow`),
porque se modifican archivos de `.github/workflows/`.

Al abrir una sesión nueva, decirle a Claude que lea `ESTADO.md`.
