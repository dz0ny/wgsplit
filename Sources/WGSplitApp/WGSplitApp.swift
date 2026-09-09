import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WGSplitKit

@main
struct WGSplitApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)

        Window("Routed Domains", id: "domains") {
            DomainsWindow(model: model)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let status = model.status {
            Text(model.healthDescription)
            Button(status.running ? "Stop" : "Start") { model.toggleEnabled() }
                .disabled(model.busy)
            Divider()
            if status.tunnels.isEmpty {
                Text("No tunnels imported")
            } else {
                ForEach(status.tunnels, id: \.id) { tunnel in
                    Button(tunnel.id == status.activeTunnelID ? "✓ \(tunnel.name)" : tunnel.name) {
                        model.setActive(tunnel.id)
                    }
                }
            }
            Divider()
            if status.rules.isEmpty {
                Text("No routed domains")
            } else {
                ForEach(status.rules.prefix(8), id: \.pattern) { Text($0.pattern) }
                if status.rules.count > 8 {
                    Text("+ \(status.rules.count - 8) more")
                }
            }
        } else {
            Text(model.errorMessage ?? "Connecting…")
        }

        Divider()
        Button("Edit Domains…") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "domains")
        }
        Button("Import Tunnels from Zip…") { importZip() }
        Button("Refresh") { model.refresh() }

        Divider()
        Button(model.startsAtLogin ? "✓ Start at Login" : "Start at Login") {
            model.toggleStartAtLogin()
        }
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .onAppear { model.refresh() }
    }

    private func importZip() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { model.importZip(at: url) }
    }
}
