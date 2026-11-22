import AppKit
import ImageCaptureCore
import UniformTypeIdentifiers

/// Una foto o video del celular.
final class PhotoItem: ObservableObject, Identifiable {
    let file: ICCameraFile
    let name: String
    let size: Int64
    let date: Date
    let isVideo: Bool

    /// Clave estable usada para detectar duplicados entre importaciones.
    let key: String
    var id: String { key }

    @Published var thumbnail: NSImage?
    var thumbnailRequested = false

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
