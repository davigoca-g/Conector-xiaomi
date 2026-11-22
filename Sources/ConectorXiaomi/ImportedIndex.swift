import Foundation

/// Registro persistente de lo ya importado, para no duplicar fotos entre sesiones.
final class ImportedIndex {
    private(set) var keys: Set<String>
    private let url: URL

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

    func contains(_ key: String) -> Bool { keys.contains(key) }

    func insert(_ key: String) {
        keys.insert(key)
        if let data = try? JSONEncoder().encode(Array(keys)) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
