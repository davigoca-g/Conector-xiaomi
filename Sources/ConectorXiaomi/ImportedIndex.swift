import Foundation

/// Registro persistente de lo ya importado, para no duplicar fotos entre sesiones.
/// Se lee desde la interfaz (hilo principal) y se escribe desde la tarea de importación (hilo secundario), por lo que
/// todo acceso al conjunto pasa por un candado. Sin él, una importación masiva cerraba la app por una carrera de datos.
final class ImportedIndex {
    private var keys: Set<String>
    private let url: URL
    private let candado = NSLock()
    /// Altas pendientes de guardar en disco. Guardar tras cada foto reescribía todo el archivo y era cuadrático.
    private var sinGuardar = 0
    private static let guardarCada = 50

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ConectorXiaomi", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("imported.json")
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([String].self, from: data) {
            keys = Set(list)
        } else {
            keys = []
        }
    }

    func contains(_ key: String) -> Bool {
        candado.lock(); defer { candado.unlock() }
        return keys.contains(key)
    }

    func insert(_ key: String) {
        candado.lock(); defer { candado.unlock() }
        keys.insert(key)
        sinGuardar += 1
        if sinGuardar >= Self.guardarCada { guardarSinCandado() }
    }

    /// Escribe en disco lo pendiente. Se llama al terminar o cancelar una importación.
    func guardar() {
        candado.lock(); defer { candado.unlock() }
        guardarSinCandado()
    }

    private func guardarSinCandado() {
        sinGuardar = 0
        if let data = try? JSONEncoder().encode(Array(keys)) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
