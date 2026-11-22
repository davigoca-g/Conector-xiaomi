import SwiftUI
import AppKit

/// Escenas con datos ficticios que sirven para generar las imágenes del manual de usuario
/// desde el propio compilador (GitHub Actions), sin necesidad de un celular conectado.
enum EscenaCaptura: String {
    case espera, galeria, importacion
}

enum Captura {
    private static let entorno = ProcessInfo.processInfo.environment

    /// Carpeta donde se guardan los PNG. Se define con la variable CONECTOR_CAPTURAS.
    static var carpeta: URL? { entorno["CONECTOR_CAPTURAS"].map { URL(fileURLWithPath: $0) } }

    /// Escena a mostrar. Se define con la variable CONECTOR_ESCENA (espera, galeria o importacion).
    static var escena: EscenaCaptura? {
        guard carpeta != nil else { return nil }
        return entorno["CONECTOR_ESCENA"].flatMap(EscenaCaptura.init(rawValue:))
    }

    /// Espera a que la ventana se dibuje, guarda la captura en PNG y cierra la app.
    static func programar() {
        guard let carpeta, let escena else { return }
        // Seguro por si la ventana nunca aparece (por ejemplo, sin sesión gráfica).
        DispatchQueue.main.asyncAfter(deadline: .now() + 40) { exit(1) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard let ventana = NSApp.windows.first(where: { $0.isVisible }) else { exit(2) }
            try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            let destino = carpeta.appendingPathComponent("\(escena.rawValue).png")
            // Primero se intenta con screencapture, que dibuja la ventana real (barra lateral translúcida incluida).
            // Si falla, se dibuja la vista directamente: sale menos fiel, pero siempre hay imagen.
            if !capturarConScreencapture(ventana, en: destino) && !dibujarVista(ventana, en: destino) { exit(3) }
            exit(0)
        }
    }

    private static func capturarConScreencapture(_ ventana: NSWindow, en destino: URL) -> Bool {
        let proceso = Process()
        proceso.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proceso.arguments = ["-x", "-o", "-l", String(ventana.windowNumber), destino.path]
        do { try proceso.run() } catch { return false }
        proceso.waitUntilExit()
        let tamano = (try? FileManager.default.attributesOfItem(atPath: destino.path)[.size] as? Int) ?? 0
        return proceso.terminationStatus == 0 && tamano > 0
    }

    private static func dibujarVista(_ ventana: NSWindow, en destino: URL) -> Bool {
        guard let vista = ventana.contentView?.superview,
              let rep = vista.bitmapImageRepForCachingDisplay(in: vista.bounds) else { return false }
        vista.cacheDisplay(in: vista.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: destino)) != nil
    }
}

extension DeviceManager {
    /// Carga los datos ficticios de una escena. La escena «espera» no carga nada: es la pantalla inicial sin celular.
    func cargarEscena(_ escena: EscenaCaptura) {
        guard escena != .espera else { return }
        demoDeviceName = "Redmi Note 12 Pro+ 5G"
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 18)) ?? Date()
        var fotos: [PhotoItem] = []
        for i in 0..<30 {
            let esVideo = i % 9 == 4
            let nombre = esVideo ? String(format: "VID_20261121_%04d.mp4", 1800 - i)
                                 : String(format: "IMG_20261121_%04d.jpg", 1800 - i)
            let fecha = base.addingTimeInterval(TimeInterval(-i * 5400))
            fotos.append(PhotoItem(demoName: nombre, date: fecha, isVideo: esVideo, hue: CGFloat((i * 37) % 100) / 100))
        }
        photos = fotos
        // Las ya importadas se reparten entre las primeras filas para que se vean atenuadas en la captura.
        demoImported = Set([0, 1, 12, 13, 14, 15, 16, 17].map { fotos[$0].key })
        state = .ready
        switch escena {
        case .galeria:
            selection = Set(fotos[2..<12].map(\.key))
        case .importacion:
            importLog = "Importadas: 10 · Duplicadas omitidas: 8 · Fallidas: 0\n"
        case .espera:
            break
        }
    }
}
