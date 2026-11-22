import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Necesario para que la ventana tome foco cuando se ejecuta con `swift run`.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ConectorXiaomiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = DeviceManager()

    var body: some Scene {
        WindowGroup("Conector Xiaomi") {
            ContentView()
                .environmentObject(manager)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { manager.start() }
        }
    }
}
