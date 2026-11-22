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

    // Importación
    @Published var destination: URL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Xiaomi", isDirectory: true)
    @Published var layout: FolderLayout = .yearMonth
    @Published var deleteAfterImport = false
    @Published var isImporting = false
    @Published var importProgress: Double = 0
    @Published var importLog: String = ""

    private let browser = ICDeviceBrowser()
    private let index = ImportedIndex()
    private var photosByObject: [ObjectIdentifier: PhotoItem] = [:]
    /// Claves que las escenas de demostración marcan como ya importadas.
    var demoImported: Set<String> = []

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

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Elegir"
        if panel.runModal() == .OK, let url = panel.url { destination = url }
    }

    // MARK: Previsualización
    /// Descarga la foto a una carpeta temporal y devuelve la imagen completa.
    func loadFullImage(_ item: PhotoItem) async -> NSImage? {
        guard let file = item.file else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ConectorXiaomiPreview", isDirectory: true)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        do {
            let name = "\(UUID().uuidString)_\(item.name)"
            _ = try await download(file, to: tmp, as: name)
            let url = tmp.appendingPathComponent(name)
            defer { try? FileManager.default.removeItem(at: url) }
            return NSImage(contentsOf: url)
        } catch {
            return nil
        }
    }

    // MARK: Importación
    func importSelected() {
        let items = photos.filter { selection.contains($0.key) }
        guard !items.isEmpty, !isImporting else { return }
        isImporting = true
        importProgress = 0
        importLog = ""
        let dest = destination, layout = layout, deleteAfter = deleteAfterImport

        Task {
            var imported = 0, skipped = 0, failed = 0
            var verified: [PhotoItem] = []
            let fm = FileManager.default

            for (i, item) in items.enumerated() {
                defer { Task { @MainActor in self.importProgress = Double(i + 1) / Double(items.count) } }

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
                    _ = try await download(file, to: folder, as: finalName)

                    let out = folder.appendingPathComponent(finalName)
                    let size = (try fm.attributesOfItem(atPath: out.path)[.size] as? NSNumber)?.int64Value ?? -1
                    guard size == item.size else {
                        try? fm.removeItem(at: out)
                        throw NSError(domain: "Conector", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "Tamaño distinto tras copiar"])
                    }
                    // Conserva la fecha original de la foto.
                    try? fm.setAttributes([.creationDate: item.date, .modificationDate: item.date], ofItemAtPath: out.path)
                    index.insert(item.key)
                    imported += 1
                    verified.append(item)
                } catch {
                    failed += 1
                    await MainActor.run { self.importLog += "✗ \(item.name): \(error.localizedDescription)\n" }
                }
            }

            // Solo se borra del celular lo verificado en el Mac.
            if deleteAfter, !verified.isEmpty, let device = await MainActor.run(body: { self.selectedDevice }) {
                device.requestDeleteFiles(verified.compactMap(\.file))
            }

            await MainActor.run {
                self.importLog = "Importadas: \(imported) · Duplicadas omitidas: \(skipped) · Fallidas: \(failed)\n" + self.importLog
                self.isImporting = false
                self.selection = []
                self.objectWillChange.send()
            }
        }
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
