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
            Image(systemName: model.isRunning ? "lock.shield.fill" : "lock.shield")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if let status = model.status {
            Text(status.running ? "Connected" : "Stopped")
            Button(status.running ? "Stop" : "Start") { model.toggleEnabled() }
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
                ForEach(status.rules, id: \.pattern) { Text($0.pattern) }
            }
        } else {
            Text(model.errorMessage ?? "Connecting…")
        }

        Divider()
        Button("Import Tunnels from Zip…") { importZip() }
        Button("Edit Domains…") { editDomains() }
        Button("Refresh") { model.refresh() }
        Divider()
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

    private func editDomains() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Routed domains"
        alert.informativeText =
            "One pattern per line. *.niteo.co matches niteo.co and its subdomains."
        let text = NSTextView(frame: NSRect(x: 0, y: 0, width: 320, height: 120))
        text.string = (model.status?.rules ?? []).map(\.pattern).joined(separator: "\n")
        text.isEditable = true
        let scroll = NSScrollView(frame: text.frame)
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        alert.accessoryView = scroll
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.setRules(text.string.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })
    }
}
