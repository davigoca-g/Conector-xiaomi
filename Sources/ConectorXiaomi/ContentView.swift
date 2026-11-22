import SwiftUI
import AVKit
import ImageCaptureCore

struct ContentView: View {
    @EnvironmentObject var manager: DeviceManager
    @State private var previewItem: PhotoItem?
    @State private var mostrandoRango = false
    @State private var rangoDesde = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var rangoHasta = Date()

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
            if manager.modoLista { listaFotos } else { cuadriculaFotos }
            Divider()
            importBar
        }
        .navigationTitle(manager.selectedDevice?.name ?? manager.demoDeviceName ?? "Galería")
        .navigationSubtitle("\(manager.photos.count) elementos · \(manager.selection.count) seleccionados")
        .toolbar {
            ToolbarItem {
                Button("Importar solo lo nuevo") { manager.importarNuevas() }
                    .disabled(manager.isImporting)
                    .help("Selecciona lo que aún no se ha importado y lo importa de una vez")
            }
            ToolbarItem {
                Button("Seleccionar nuevas") { manager.selectAllNew() }
            }
            ToolbarItem { menuLotes }
            ToolbarItem {
                Picker("Vista", selection: $manager.modoLista) {
                    Label("Lista", systemImage: "list.bullet").tag(true)
                    Label("Miniaturas", systemImage: "square.grid.2x2").tag(false)
                }
                .pickerStyle(.segmented)
                .help("La lista no descarga miniaturas y es la más rápida con muchas fotos")
            }
            ToolbarItem {
                Button("Limpiar") { manager.selection = [] }.disabled(manager.selection.isEmpty)
            }
        }
    }

    // MARK: Lista y cuadrícula
    private var cuadriculaFotos: some View {
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
    }

    /// Lista sin miniaturas: no se le pide nada al celular, así que abre al instante aunque haya decenas de miles de fotos.
    private var listaFotos: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(manager.photos) { item in
                    FilaFoto(item: item,
                             selected: manager.selection.contains(item.key),
                             imported: manager.isAlreadyImported(item),
                             vistaPrevia: { previewItem = item })
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { previewItem = item }
                        .onTapGesture { toggle(item) }
                    Divider()
                }
            }
        }
    }

    // MARK: Selección por lotes
    private var menuLotes: some View {
        Menu("Seleccionar por lote") {
            Toggle("Omitir las ya importadas", isOn: $manager.omitirImportadas)
            Divider()
            Button("Todo") { manager.seleccionarTodo() }
            Button("Último mes") { manager.seleccionarUltimos(.month, 1) }
            Button("Últimos 3 meses") { manager.seleccionarUltimos(.month, 3) }
            Button("Último semestre") { manager.seleccionarUltimos(.month, 6) }
            Button("Último año") { manager.seleccionarUltimos(.year, 1) }
            if !manager.aniosDisponibles.isEmpty {
                Divider()
                ForEach(manager.aniosDisponibles, id: \.self) { anio in
                    Button("Año \(String(anio))") { manager.seleccionarAnio(anio) }
                }
            }
            Divider()
            Button("Rango de fechas…") { mostrandoRango = true }
        }
        .help("Marca de una vez todas las fotos de un periodo para importarlas por lotes")
        .popover(isPresented: $mostrandoRango) { selectorRango }
    }

    private var selectorRango: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Desde", selection: $rangoDesde, displayedComponents: .date)
            DatePicker("Hasta", selection: $rangoHasta, displayedComponents: .date)
            HStack {
                Spacer()
                Button("Cancelar") { mostrandoRango = false }.keyboardShortcut(.cancelAction)
                Button("Seleccionar") {
                    manager.seleccionarRango(rangoDesde, rangoHasta)
                    mostrandoRango = false
                }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func toggle(_ item: PhotoItem) {
        if manager.selection.contains(item.key) { manager.selection.remove(item.key) }
        else { manager.selection.insert(item.key) }
    }

    // MARK: Barra de importación
    private var resumenSeleccion: String {
        var texto = "Por copiar: \(DeviceManager.formatoBytes(manager.bytesSeleccionados))"
        if let libre = manager.espacioLibre() {
            texto += " · Libre en el destino: \(DeviceManager.formatoBytes(libre))"
            if sinEspacio { texto += " · ESPACIO INSUFICIENTE" }
        }
        return texto
    }

    private var sinEspacio: Bool {
        guard let libre = manager.espacioLibre() else { return false }
        return manager.bytesSeleccionados > libre
    }

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
                Button("Importar \(manager.selection.count)") { manager.importSelected() }
                    .buttonStyle(.borderedProminent)
                    .disabled(manager.selection.isEmpty || manager.isImporting)
            }
            HStack(spacing: 12) {
                Text(resumenSeleccion)
                    .font(.caption)
                    .foregroundStyle(sinEspacio ? Color.red : Color.secondary)
                Spacer()
                if manager.isImporting {
                    Text(manager.importStatus).font(.caption).foregroundStyle(.secondary)
                    ProgressView(value: manager.importProgress).frame(width: 120)
                    Button(manager.isCancelling ? "Cancelando…" : "Cancelar") { manager.cancelarImportacion() }
                        .disabled(manager.isCancelling)
                }
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

// MARK: - Fila de la lista
struct FilaFoto: View {
    let item: PhotoItem
    let selected: Bool
    let imported: Bool
    let vistaPrevia: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selected ? Color.accentColor : .secondary)
            Image(systemName: item.isVideo ? "video" : "photo").foregroundStyle(.secondary)
            Text(item.name).lineLimit(1)
            Spacer()
            if imported { Text("Ya importada").font(.caption).foregroundStyle(.secondary) }
            Text(item.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
            Text(DeviceManager.formatoBytes(item.size)).foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Button { vistaPrevia() } label: { Image(systemName: "eye") }
                .buttonStyle(.borderless)
                .help("Ver vista previa (descarga el archivo del celular)")
        }
        .font(.callout)
        .padding(.horizontal, 12).padding(.vertical, 5)
        .background(selected ? Color.accentColor.opacity(0.12) : .clear)
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
    @State private var player: AVPlayer?
    @State private var videoURL: URL?
    @State private var loading = true
    /// En la vista de lista la descarga solo empieza cuando el usuario la confirma.
    @State private var iniciado = false

    var body: some View {
        VStack {
            HStack {
                Text(item.name).font(.headline)
                Spacer()
                Button("Cerrar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            ZStack {
                if !iniciado {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Para ver la vista previa hay que descargar el archivo completo del celular "
                             + "(\(DeviceManager.formatoBytes(item.size))).")
                        Text("Con una biblioteca tan grande el celular responde despacio y puede demorar.")
                            .foregroundStyle(.secondary)
                        Button("Cargar vista previa") { iniciado = true }.buttonStyle(.borderedProminent)
                    }
                    .multilineTextAlignment(.center).padding()
                }
                else if let player { VideoPlayer(player: player) }
                else if let image { Image(nsImage: image).resizable().scaledToFit() }
                else {
                    // Mientras baja el archivo completo se muestra la miniatura para que la ventana nunca quede vacía.
                    if let miniatura = item.thumbnail {
                        Image(nsImage: miniatura).resizable().scaledToFit().opacity(loading ? 0.5 : 1)
                    }
                    if loading {
                        ProgressView(item.isVideo ? "Descargando video…" : "Descargando foto completa…")
                            .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Text("No se pudo cargar la vista previa completa. Revisa que el celular siga conectado y desbloqueado.")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .frame(width: 800, height: 600)
        .task(id: iniciado) {
            if !iniciado {
                if !manager.modoLista { iniciado = true }
                return
            }
            if item.isVideo {
                if let url = await manager.loadVideo(item) {
                    videoURL = url
                    player = AVPlayer(url: url)
                }
            } else {
                image = await manager.loadFullImage(item)
            }
            loading = false
        }
        .onDisappear {
            player?.pause()
            if let videoURL { try? FileManager.default.removeItem(at: videoURL) }
        }
    }
}

private extension URL {
    var abbreviatedPath: String { (path as NSString).abbreviatingWithTildeInPath }
}
