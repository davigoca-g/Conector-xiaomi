import AppKit
import ImageCaptureCore
import UniformTypeIdentifiers

/// Una foto o video del celular.
final class PhotoItem: ObservableObject, Identifiable {
    /// Es nil solo en las fotos ficticias de las escenas de demostración.
    let file: ICCameraFile?
    let name: String
    let size: Int64
    let date: Date
    let isVideo: Bool

    /// Clave estable usada para detectar duplicados entre importaciones.
    let key: String
    var id: String { key }

    @Published var thumbnail: NSImage?
    var thumbnailRequested = false

    /// Foto ficticia con miniatura dibujada, usada solo para generar las capturas del manual.
    init(demoName: String, date: Date, isVideo: Bool, hue: CGFloat) {
        self.file = nil
        self.name = demoName
        self.size = 3_500_000
        self.date = date
        self.isVideo = isVideo
        self.key = "demo|\(demoName)"
        self.thumbnail = Self.dibujarMiniatura(hue: hue)
        self.thumbnailRequested = true
    }

    private static func dibujarMiniatura(hue: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: 130, height: 130), flipped: false) { rect in
            let cielo = NSGradient(starting: NSColor(hue: hue, saturation: 0.45, brightness: 0.98, alpha: 1),
                                   ending: NSColor(hue: hue, saturation: 0.15, brightness: 1, alpha: 1))
            cielo?.draw(in: rect, angle: 90)
            NSColor(white: 1, alpha: 0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: 80, y: 82, width: 28, height: 28)).fill()
            NSColor(hue: hue, saturation: 0.55, brightness: 0.55, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: -30, y: -50, width: 140, height: 100)).fill()
            NSColor(hue: hue, saturation: 0.6, brightness: 0.4, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: 40, y: -60, width: 130, height: 90)).fill()
            return true
        }
    }

    init?(file: ICCameraFile) {
        let name = file.name ?? "sin_nombre"
        let ext = (name as NSString).pathExtension.lowercased()
        let type = UTType(filenameExtension: ext)
        let uti = file.uti.flatMap { UTType($0) } ?? type
        guard let uti, uti.conforms(to: .image) || uti.conforms(to: .movie) else { return nil }

        self.file = file
        self.name = name
        self.size = file.fileSize
        self.date = file.creationDate ?? file.modificationDate ?? Date(timeIntervalSince1970: 0)
        self.isVideo = uti.conforms(to: .movie)
        self.key = "\(name)|\(file.fileSize)|\(Int(date.timeIntervalSince1970))"
    }
}
