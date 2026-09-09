import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WGSplitKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettings(model: model)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(0)
            TunnelSettings(model: model)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Tunnels", systemImage: "network") }
                .tag(1)
            RoutesSettings(model: model)
                .fixedSize(horizontal: false, vertical: true)
                .tabItem { Label("Routes", systemImage: "arrow.triangle.branch") }
                .tag(2)
        }
        .padding(20)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .safeAreaInset(edge: .bottom) {
            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { model.refresh() }
    }
}

private struct GeneralSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsNote(text: "Choose how wgsplit starts and check the tunnel connection.")
            SettingsSection(title: "Startup") {
                Toggle("Start at Login", isOn: Binding(
                    get: { model.startsAtLogin },
                    set: { _ in model.toggleStartAtLogin() }
                ))
                SettingsNote(text: "Open wgsplit in the menu bar when you log in to your Mac.")
            }
            SettingsSection(title: "Connection") {
                LabeledContent("Status", value: model.headline)
                SettingsNote(text: "Use Start or Stop in the menu bar to control the tunnel. Only the domains in Routes use this connection.")
                if model.status == nil {
                    Divider()
                    Button(model.installing ? "Installing Helper…" : "Install Helper…") {
                        model.installHelper()
                    }
                    .disabled(model.busy)
                    SettingsNote(text: "The helper controls the tunnel. Installation requires an administrator password.")
                }
            }
            SettingsSection(title: "Updates") {
                Toggle("Check for new versions automatically", isOn: $model.autoCheckUpdates)
                LabeledContent("Installed version", value: model.installedVersion)
                if let update = model.availableUpdate {
                    LabeledContent("Available version", value: update.tagName)
                    Button(model.updating ? "Updating…" : "Install and Relaunch") {
                        model.installUpdate()
                    }
                    .disabled(model.updating)
                } else {
                    Button("Check for Update") {
                        Task { await model.checkForUpdate() }
                    }
                    .disabled(!SelfUpdater.isBundled)
                }
                SettingsNote(text: "Updates replace the app only. Reinstall the helper afterwards if the menu reports a problem.")
                if let error = model.updateError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

private struct TunnelSettings: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsNote(text: "Import your WireGuard configurations and choose a tunnel for your routes.")
            SettingsSection(title: "Active Tunnel") {
                if let status = model.status, !status.tunnels.isEmpty {
                    Picker("Tunnel", selection: Binding<UUID?>(
                        get: { model.status?.activeTunnelID },
                        set: { model.setActive($0) }
                    )) {
                        Text("None").tag(nil as UUID?)
                        ForEach(status.tunnels, id: \.id) { tunnel in
                            Text(tunnel.name).tag(Optional(tunnel.id))
                        }
                    }
                    .disabled(model.busy)
                    if let tunnel = status.tunnels.first(where: { $0.id == status.activeTunnelID }) {
                        LabeledContent("Addresses", value: tunnel.addresses.joined(separator: ", "))
                    }
                } else {
                    Text("No tunnels imported yet.")
                        .foregroundStyle(.secondary)
                }
                SettingsNote(text: "All configured routes use this tunnel. Changing it restarts a running connection and resets the traffic estimate.")
            }
            SettingsSection(title: "Import Configurations") {
                SettingsNote(text: "Choose a ZIP file that contains WireGuard configuration files. After import, select the tunnel you want to use above.")
                Button("Import Tunnels…", action: importZip)
                    .disabled(model.status == nil || model.busy)
            }
        }
        .padding(.vertical, 12)
    }

    private func importZip() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { model.importZip(at: url) }
    }
}

struct SettingsNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        } label: {
            Text(title).font(.headline)
        }
    }
}
