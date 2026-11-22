import SwiftUI
import ImageCaptureCore

struct ContentView: View {
    @EnvironmentObject var manager: DeviceManager
    @State private var previewItem: PhotoItem?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .sheet(item: $previewItem) { PreviewSheet(item: $0) }
    }

    // MARK: Barra lateral
    private var sidebar: some View {
        List(selection: Binding(
            get: { manager.selectedDevice.map { ObjectIdentifier($0) } },
            set: { id in
                if let d = manager.devices.first(where: { ObjectIdentifier($0) == id }) { manager.select(d) }
            })) {
            Section("Dispositivos") {
                ForEach(manager.devices, id: \.self) { device in
                    Label(device.name ?? "Dispositivo", systemImage: "iphone")
                        .tag(ObjectIdentifier(device))
                }
                if let nombre = manager.demoDeviceName {
                    Label(nombre, systemImage: "iphone")
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        .overlay {
            if manager.devices.isEmpty && manager.demoDeviceName == nil {
                ContentUnavailableView("Sin dispositivos", systemImage: "cable.connector",
                                       description: Text("Conecta el Xiaomi por USB."))
                    .padding()
            }
        }
    }

    // MARK: Detalle
    @ViewBuilder private var detail: some View {
        switch manager.state {
        case .idle:
            VStack(spacing: 12) {
                ContentUnavailableView("Conecta tu Xiaomi", systemImage: "iphone.and.arrow.forward",
                    description: Text("""
                    1. Conecta el cable USB y desbloquea el celular.
                    2. En el aviso de USB elige «Transferir fotos (PTP)».
                    3. Si no aparece, ve a Ajustes ▸ Opciones de desarrollador ▸ Configuración USB predeterminada ▸ PTP.
                    """))
            }
        case .opening, .loadingCatalog:
            VStack(spacing: 12) {
                ProgressView()
                Text(manager.state == .opening ? "Abriendo sesión…" : "Leyendo fotos… \(manager.photos.count)")
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            ContentUnavailableView("No se pudo leer el celular", systemImage: "exclamationmark.triangle",
                                   description: Text(message))
        case .ready:
            gallery
        }
    }

    private var gallery: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130, maximum: 160), spacing: 8)], spacing: 8) {
                    ForEach(manager.photos) { item in
                        ThumbnailCell(item: item,
                                      selected: manager.selection.contains(item.key),
                                      imported: manager.isAlreadyImported(item))
                            .onTapGesture(count: 2) { previewItem = item }
                            .onTapGesture { toggle(item) }
                    }
                }
                .padding(10)
            }
            Divider()
            importBar
        }
        .navigationTitle(manager.selectedDevice?.name ?? manager.demoDeviceName ?? "Galería")
        .navigationSubtitle("\(manager.photos.count) elementos · \(manager.selection.count) seleccionados")
        .toolbar {
            ToolbarItem {
                Button("Seleccionar nuevas") { manager.selectAllNew() }
            }
            ToolbarItem {
                Button("Limpiar") { manager.selection = [] }.disabled(manager.selection.isEmpty)
            }
        }
    }

    private func toggle(_ item: PhotoItem) {
        if manager.selection.contains(item.key) { manager.selection.remove(item.key) }
        else { manager.selection.insert(item.key) }
    }

    // MARK: Barra de importación
    private var importBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { manager.chooseDestination() } label: {
                    Label(manager.destination.abbreviatedPath, systemImage: "folder")
                }
                Picker("Organizar", selection: $manager.layout) {
                    ForEach(FolderLayout.allCases) { Text($0.rawValue).tag($0) }
                }.frame(width: 250)
                Toggle("Borrar del celular tras verificar", isOn: $manager.deleteAfterImport)
                Spacer()
                if manager.isImporting {
                    ProgressView(value: manager.importProgress).frame(width: 140)
                }
                Button("Importar \(manager.selection.count)") { manager.importSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(manager.selection.isEmpty || manager.isImporting)
            }
            if !manager.importLog.isEmpty {
                ScrollView { Text(manager.importLog).font(.caption.monospaced()).frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(maxHeight: 60)
            }
        }
        .padding(10)
        .background(.bar)
    }
}

// MARK: - Miniatura
struct ThumbnailCell: View {
    @ObservedObject var item: PhotoItem
    let selected: Bool
    let imported: Bool
    @EnvironmentObject var manager: DeviceManager

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = item.thumbnail {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(.quaternary).overlay(ProgressView().controlSize(.small))
                }
            }
            .frame(width: 130, height: 130)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if item.isVideo { Image(systemName: "video.fill").padding(4).foregroundStyle(.white).shadow(radius: 2) }
            }
            .overlay { if imported { Color.black.opacity(0.35) } }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? Color.accentColor : .clear, lineWidth: 3))

            if selected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor, .white).padding(4)
            } else if imported {
                Image(systemName: "arrow.down.circle.fill").foregroundStyle(.white).padding(4)
            }
        }
        .help("\(item.name)\n\(item.date.formatted())\(imported ? "\nYa importada" : "")")
        .onAppear { manager.requestThumbnail(for: item) }
    }
}

// MARK: - Previsualización
struct PreviewSheet: View {
    let item: PhotoItem
    @EnvironmentObject var manager: DeviceManager
    @Environment(\.dismiss) private var dismiss
    @State private var image: NSImage?
    @State private var loading = true

    var body: some View {
        VStack {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                Button("Cerrar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ZStack {
                if let image { Image(nsImage: image).resizable().scaledToFit() }
                else if loading { ProgressView("Descargando…") }
                else { Text(item.isVideo ? "Vista previa de video no disponible" : "No se pudo cargar").foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(width: 800, height: 600)
        .task {
            if !item.isVideo { image = await manager.loadFullImage(item) }
            loading = false
        }
    }
}

private extension URL {
    var abbreviatedPath: String { (path as NSString).abbreviatingWithTildeInPath }
}
