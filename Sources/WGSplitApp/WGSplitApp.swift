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
        Text(model.headline)

        if let status = model.status {
            Button(status.running ? "Stop" : "Start") { model.toggleEnabled() }
                .disabled(model.busy)

            if !status.tunnels.isEmpty {
                Section("Tunnel") {
                    ForEach(status.tunnels, id: \.id) { tunnel in
                        Button(tunnel.id == status.activeTunnelID ? "✓ \(tunnel.name)"
                                                                  : "   \(tunnel.name)") {
                            model.setActive(tunnel.id)
                        }
                    }
                }
            }

            Section {
                Menu(model.domainsLabel) {
                    if status.rules.isEmpty {
                        Text("Nothing is being routed")
                    } else {
                        ForEach(status.rules, id: \.pattern) { Text($0.pattern) }
                    }
                    Divider()
                    Button("Edit…") { openDomains() }
                }
                Button("Edit Domains…") { openDomains() }
                Button("Import Tunnels…") { importZip() }
            }
        } else if model.needsHelper {
            Section {
                Button("Install Helper…") { model.installHelper() }
                    .disabled(model.busy)
            }
        }

        Section {
            Button(model.startsAtLogin ? "✓ Start at Login" : "   Start at Login") {
                model.toggleStartAtLogin()
            }
            Button("Quit wgsplit") { NSApplication.shared.terminate(nil) }
                .onAppear { model.refresh() }
        }
    }

    private func openDomains() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "domains")
    }

    private func importZip() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { model.importZip(at: url) }
    }
}
