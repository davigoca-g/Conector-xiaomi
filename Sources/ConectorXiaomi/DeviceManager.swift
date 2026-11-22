import Foundation
import AppKit
import ImageCaptureCore

enum FolderLayout: String, CaseIterable, Identifiable {
    case yearMonth = "Año / Mes"
    case yearMonthDay = "Año / Mes / Día"
    case flat = "Sin subcarpetas"
    var id: String { rawValue }
}

enum DeviceState: Equatable {
    case idle
    case opening
    case loadingCatalog
    case ready
    case error(String)
}

/// Detecta celulares en modo PTP y expone su galería usando ImageCaptureCore.
final class DeviceManager: NSObject, ObservableObject {
    // MARK: Estado publicado
    @Published var devices: [ICCameraDevice] = []
    @Published var selectedDevice: ICCameraDevice?
    /// Nombre de un celular ficticio; solo se usa en las escenas de demostración de las capturas del manual.
    @Published var demoDeviceName: String?
    @Published var photos: [PhotoItem] = []
    @Published var state: DeviceState = .idle
    @Published var selection: Set<String> = []
    /// Años con fotos en el celular, del más reciente al más antiguo; alimenta el menú de selección por lotes.
    @Published var aniosDisponibles: [Int] = []
    /// Vista de lista sin miniaturas (por defecto). Con miles de fotos evita pedirle al celular una miniatura por cada una.
    @Published var modoLista = true
    /// En la selección por lotes, no marca lo que ya se importó antes.
    @Published var omitirImportadas = true

    // Importación
    @Published var destination: URL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Xiaomi", isDirectory: true)
    @Published var layout: FolderLayout = .yearMonth
    @Published var deleteAfterImport = false
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importLog: String = ""
    /// Texto de avance durante la importación (archivos, bytes y tiempo restante estimado).
    @Published var importStatus: String = ""
    @Published var isCancelling = false

    private let browser = ICDeviceBrowser()
    private let index = ImportedIndex()
    private var photosByObject: [ObjectIdentifier: PhotoItem] = [:]
    /// Claves que las escenas de demostración marcan como ya importadas.
    var demoImported: Set<String> = []
    private var cancelRequested = false

    // MARK: Ciclo de vida
    func start() {
        browser.delegate = self
        let mask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.camera.rawValue
                                    | ICDeviceLocationTypeMask.local.rawValue)
        browser.browsedDeviceTypeMask = mask ?? .camera
        browser.start()
    }

    func select(_ device: ICCameraDevice) {
        if let current = selectedDevice, current !== device { current.requestCloseSession() }
        selectedDevice = device
        photos = []
        photosByObject = [:]
        selection = []
        aniosDisponibles = []
        state = .opening
        device.delegate = self
        device.requestOpenSession()
    }

    func isAlreadyImported(_ item: PhotoItem) -> Bool { index.contains(item.key) || demoImported.contains(item.key) }

    func requestThumbnail(for item: PhotoItem) {
        guard !item.thumbnailRequested else { return }
        item.thumbnailRequested = true
        item.file?.requestThumbnail()
    }

    func selectAllNew() {
        selection = Set(photos.filter { !isAlreadyImported($0) }.map(\.key))
    }

    // MARK: Selección por lotes
    /// Reemplaza la selección por las fotos cuya fecha cae en el rango. Un extremo nulo deja ese lado abierto.
    /// Si `omitirImportadas` está activo, las que ya se importaron antes no se marcan.
    func seleccionar(desde: Date?, hasta: Date?) {
        selection = Set(photos.lazy.filter { item in
            if let desde, item.date < desde { return false }
            if let hasta, item.date >= hasta { return false }
            return !(self.omitirImportadas && self.isAlreadyImported(item))
        }.map(\.key))
    }

    func seleccionarTodo() { seleccionar(desde: nil, hasta: nil) }

    /// Selecciona lo tomado en los últimos `valor` días, meses o años, contando desde ahora.
    func seleccionarUltimos(_ unidad: Calendar.Component, _ valor: Int) {
        seleccionar(desde: Calendar.current.date(byAdding: unidad, value: -valor, to: Date()), hasta: nil)
    }

    func seleccionarAnio(_ anio: Int) {
        let cal = Calendar.current
        guard let inicio = cal.date(from: DateComponents(year: anio)),
              let fin = cal.date(from: DateComponents(year: anio + 1)) else { return }
        seleccionar(desde: inicio, hasta: fin)
    }

    /// Selecciona un rango de días completos: desde el inicio del primero hasta el final del último, ambos inclusive.
    func seleccionarRango(_ primero: Date, _ ultimo: Date) {
        let cal = Calendar.current
        let fin = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: max(primero, ultimo)))
        seleccionar(desde: cal.startOfDay(for: min(primero, ultimo)), hasta: fin)
    }

    private func recalcularAnios() {
        let cal = Calendar.current
        aniosDisponibles = Set(photos.map { cal.component(.year, from: $0.date) }).sorted(by: >)
    }

    /// Selecciona todo lo que aún no se importó y lo importa en un solo paso.
    func importarNuevas() {
        guard !isImporting else { return }
        selectAllNew()
        if selection.isEmpty {
            importLog = "No hay fotos nuevas para importar.\n"
            return
        }
        importSelected()
    }

    /// Pide detener la importación. El archivo en curso termina de copiarse y los siguientes quedan sin importar.
    func cancelarImportacion() {
        guard isImporting else { return }
        cancelRequested = true
        isCancelling = true
    }

    /// Bytes que faltan por copiar de la selección actual (sin contar lo ya importado).
    var bytesSeleccionados: Int64 {
        photos.reduce(Int64(0)) { total, item in
            selection.contains(item.key) && !isAlreadyImported(item) ? total + item.size : total
        }
    }

    /// Espacio libre en el disco del destino. Si la carpeta aún no existe, mide el primer directorio existente hacia arriba.
    func espacioLibre() -> Int64? {
        var url = destination
        while !FileManager.default.fileExists(atPath: url.path), url.pathComponents.count > 1 {
            url = url.deletingLastPathComponent()
        }
        let valores = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return valores?.volumeAvailableCapacityForImportantUsage
    }

    static func formatoBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Elegir"
        if panel.runModal() == .OK, let url = panel.url { destination = url }
    }

    // MARK: Previsualización
    /// Descarga la foto a una carpeta temporal y devuelve la imagen lista para mostrar.
    /// La decodificación se hace antes de borrar el archivo temporal (`NSImage(contentsOf:)` es perezoso y dejaba la
    /// vista en blanco al desaparecer el archivo) y se reduce a 2400 px para no cargar en memoria fotos de 200 MP enteras.
    func loadFullImage(_ item: PhotoItem) async -> NSImage? {
        guard let file = item.file else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ConectorXiaomiPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        do {
            let name = "\(UUID().uuidString)_\(item.name)"
            _ = try await download(file, to: tmp, as: name)
            let url = tmp.appendingPathComponent(name)
            defer { try? FileManager.default.removeItem(at: url) }
            let opciones: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2400
            ]
            guard let origen = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateThumbnailAtIndex(origen, 0, opciones as CFDictionary) else { return nil }
            return NSImage(cgImage: cg, size: .zero)
        } catch {
            return nil
        }
    }

    /// Descarga el video a una carpeta temporal y devuelve su URL. Quien la pide debe borrar el archivo al terminar.
    func loadVideo(_ item: PhotoItem) async -> URL? {
        guard let file = item.file else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ConectorXiaomiPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let name = "\(UUID().uuidString)_\(item.name)"
        do {
            _ = try await download(file, to: tmp, as: name)
            return tmp.appendingPathComponent(name)
        } catch {
            return nil
        }
    }

    // MARK: Importación
    func importSelected() {
        let items = photos.filter { selection.contains($0.key) }
        guard !items.isEmpty, !isImporting else { return }
        let pendientes = items.filter { !index.contains($0.key) }
        let totalBytes = pendientes.reduce(Int64(0)) { $0 + $1.size }
        importLog = ""

        // Antes de copiar se comprueba que el disco de destino tenga espacio para todo.
        if let libre = espacioLibre(), totalBytes > libre {
            importLog = "Espacio insuficiente en el destino: se necesitan \(Self.formatoBytes(totalBytes)) y hay "
                + "\(Self.formatoBytes(libre)) libres. Libera espacio o elige otra carpeta.\n"
            return
        }

        isImporting = true
        cancelRequested = false
        isCancelling = false
        importProgress = 0
        importStatus = ""
        let dest = destination, layout = layout, deleteAfter = deleteAfterImport

        Task {
            var imported = 0, skipped = 0, failed = 0
            var cancelled = false
            var verified: [PhotoItem] = []
            var copiedBytes: Int64 = 0
            let start = Date()
            let fm = FileManager.default

            for (i, item) in items.enumerated() {
                if await MainActor.run(body: { self.cancelRequested }) { cancelled = true; break }
                await self.actualizarAvance(hechos: i, total: items.count, bytes: copiedBytes,
                                            bytesTotales: totalBytes, desde: start)

                if index.contains(item.key) { skipped += 1; verified.append(item); continue }

                let folder = Self.folder(for: item.date, layout: layout, base: dest)
                do {
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)

                    // ¿Ya existe un archivo idéntico (mismo nombre y tamaño)? Entonces es duplicado.
                    let existing = folder.appendingPathComponent(item.name)
                    if let attrs = try? fm.attributesOfItem(atPath: existing.path),
                       (attrs[.size] as? NSNumber)?.int64Value == item.size {
                        index.insert(item.key); skipped += 1; verified.append(item); continue
                    }

                    guard let file = item.file else { continue }
                    let finalName = Self.uniqueName(item.name, in: folder)
                    let out = folder.appendingPathComponent(finalName)

                    // Se copia con extensión .parte y solo se renombra cuando el tamaño coincide, de modo que
                    // un corte del cable nunca deja un archivo incompleto con el nombre definitivo.
                    let parcial = folder.appendingPathComponent(finalName + ".parte")
                    try? fm.removeItem(at: parcial)
                    do {
                        _ = try await download(file, to: folder, as: parcial.lastPathComponent)
                        let size = (try fm.attributesOfItem(atPath: parcial.path)[.size] as? NSNumber)?.int64Value ?? -1
                        guard size == item.size else {
                            throw NSError(domain: "Conector", code: 1,
                                          userInfo: [NSLocalizedDescriptionKey: "Tamaño distinto tras copiar"])
                        }
                        try fm.moveItem(at: parcial, to: out)
                    } catch {
                        try? fm.removeItem(at: parcial)
                        throw error
                    }

                    // Conserva la fecha original de la foto.
                    try? fm.setAttributes([.creationDate: item.date, .modificationDate: item.date], ofItemAtPath: out.path)
                    index.insert(item.key)
                    imported += 1
                    copiedBytes += item.size
                    verified.append(item)
                } catch {
                    failed += 1
                    copiedBytes += item.size
                    await MainActor.run { self.importLog += "✗ \(item.name): \(error.localizedDescription)\n" }
                }
            }

            // El índice guarda por tandas; aquí se escribe lo que haya quedado pendiente.
            index.guardar()

            // Solo se borra del celular lo verificado en el Mac, y nunca si la importación se canceló.
            let borrar = deleteAfter && !cancelled && !verified.isEmpty
            if borrar, let device = await MainActor.run(body: { self.selectedDevice }) {
                device.requestDeleteFiles(verified.compactMap(\.file))
            }

            await MainActor.run {
                // Lo que quedó sin importar (cancelado o fallido) sigue seleccionado para reanudar.
                let restantes = items.filter { !self.index.contains($0.key) }
                if cancelled {
                    self.importLog = "Importación cancelada. Importadas: \(imported) · Duplicadas omitidas: \(skipped) · "
                        + "Fallidas: \(failed). Quedan \(restantes.count) sin importar: pulsa Importar para reanudar. "
                        + "No se borró nada del celular.\n" + self.importLog
                } else {
                    self.importLog = "Importadas: \(imported) · Duplicadas omitidas: \(skipped) · Fallidas: \(failed)\n"
                        + self.importLog
                }
                self.selection = Set(restantes.map(\.key))
                self.importStatus = ""
                self.isImporting = false
                self.isCancelling = false
                self.objectWillChange.send()
            }
        }
    }

    @MainActor
    private func actualizarAvance(hechos: Int, total: Int, bytes: Int64, bytesTotales: Int64, desde inicio: Date) {
        importProgress = bytesTotales > 0 ? Double(bytes) / Double(bytesTotales) : Double(hechos) / Double(max(total, 1))
        var texto = "\(hechos) de \(total) · \(Self.formatoBytes(bytes)) de \(Self.formatoBytes(bytesTotales))"
        let segundos = Date().timeIntervalSince(inicio)
        if bytes > 0, segundos > 3, bytesTotales > bytes {
            let restante = Double(bytesTotales - bytes) / (Double(bytes) / segundos)
            texto += restante < 60 ? " · queda menos de 1 min" : " · quedan ~\(Int((restante / 60).rounded(.up))) min"
        }
        importStatus = texto
    }

    // MARK: Utilidades
    private func download(_ file: ICCameraFile, to folder: URL, as name: String) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let options: [ICDownloadOption: Any] = [
                .downloadsDirectoryURL: folder,
                .saveAsFilename: name,
                .overwrite: false
            ]
            file.requestDownload(options: options) { savedName, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: savedName ?? name) }
            }
        }
    }

    private static func folder(for date: Date, layout: FolderLayout, base: URL) -> URL {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = String(format: "%04d", c.year ?? 0)
        let m = String(format: "%02d", c.month ?? 0)
        let d = String(format: "%02d", c.day ?? 0)
        switch layout {
        case .yearMonth: return base.appendingPathComponent(y).appendingPathComponent(m)
        case .yearMonthDay: return base.appendingPathComponent(y).appendingPathComponent(m).appendingPathComponent(d)
        case .flat: return base
        }
    }

    private static func uniqueName(_ name: String, in folder: URL) -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.appendingPathComponent(name).path) else { return name }
        let ns = name as NSString
        let base = ns.deletingPathExtension, ext = ns.pathExtension
        var n = 1
        while true {
            let candidate = ext.isEmpty ? "\(base)_\(n)" : "\(base)_\(n).\(ext)"
            if !fm.fileExists(atPath: folder.appendingPathComponent(candidate).path) { return candidate }
            n += 1
        }
    }
}

// MARK: - Detección de dispositivos
extension DeviceManager: ICDeviceBrowserDelegate {
    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        guard let camera = device as? ICCameraDevice else { return }
        DispatchQueue.main.async {
            self.devices.append(camera)
            if self.selectedDevice == nil { self.select(camera) }
        }
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        DispatchQueue.main.async {
            self.devices.removeAll { $0 === device }
            if self.selectedDevice === device {
                self.selectedDevice = nil
                self.photos = []
                self.selection = []
                self.state = .idle
            }
        }
    }
}

// MARK: - Sesión con el celular y catálogo de archivos
extension DeviceManager: ICCameraDeviceDelegate {
    func didRemove(_ device: ICDevice) {}

    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        DispatchQueue.main.async {
            if let error { self.state = .error(error.localizedDescription) }
            else { self.state = .loadingCatalog }
        }
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {}

    func deviceDidBecomeReady(withCompleteContentCatalog device: ICCameraDevice) {
        DispatchQueue.main.async {
            self.state = .ready
            self.photos.sort { $0.date > $1.date }
            self.recalcularAnios()
        }
    }

    func cameraDevice(_ camera: ICCameraDevice, didAdd items: [ICCameraItem]) {
        let newItems = items.compactMap { ($0 as? ICCameraFile).flatMap(PhotoItem.init(file:)) }
        DispatchQueue.main.async {
            for item in newItems {
                if let file = item.file { self.photosByObject[ObjectIdentifier(file)] = item }
                self.photos.append(item)
            }
        }
    }

    func cameraDevice(_ camera: ICCameraDevice, didRemove items: [ICCameraItem]) {
        DispatchQueue.main.async {
            let ids = Set(items.map { ObjectIdentifier($0) })
            self.photos.removeAll { photo in photo.file.map { ids.contains(ObjectIdentifier($0)) } ?? false }
            self.selection = self.selection.intersection(Set(self.photos.map(\.key)))
            self.recalcularAnios()
        }
    }

    func cameraDevice(_ camera: ICCameraDevice, didReceiveThumbnail thumbnail: CGImage?,
                      for item: ICCameraItem, error: Error?) {
        guard let thumbnail else { return }
        let image = NSImage(cgImage: thumbnail, size: .zero)
        DispatchQueue.main.async {
            self.photosByObject[ObjectIdentifier(item)]?.thumbnail = image
        }
    }

    func cameraDevice(_ camera: ICCameraDevice, didReceiveMetadata metadata: [AnyHashable: Any]?,
                      for item: ICCameraItem, error: Error?) {}
    func cameraDevice(_ camera: ICCameraDevice, didRenameItems items: [ICCameraItem]) {}
    func cameraDeviceDidChangeCapability(_ camera: ICCameraDevice) {}
    func cameraDevice(_ camera: ICCameraDevice, didReceivePTPEvent eventData: Data) {}
    func cameraDeviceDidRemoveAccessRestriction(_ device: ICDevice) {}

    func cameraDeviceDidEnableAccessRestriction(_ device: ICDevice) {
        DispatchQueue.main.async {
            self.state = .error("El celular está bloqueado. Desbloquéalo y acepta el acceso a los archivos.")
        }
    }

    func cameraDevice(_ scanner: ICCameraDevice, didCompleteDeleteFilesWithError error: Error?) {
        DispatchQueue.main.async {
            if let error { self.importLog += "✗ Borrado en el celular: \(error.localizedDescription)\n" }
            else { self.importLog += "✓ Archivos verificados borrados del celular\n" }
        }
    }
}
