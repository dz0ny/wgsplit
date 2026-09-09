import SwiftUI
import AppKit
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
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openSettings) private var openSettings
    @State private var panelWindow = MenuPanelWindow()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: model.menuBarSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 36, height: 36)
                    .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("wgsplit")
                        .font(.headline)
                    Text(model.headline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if model.busy {
                    ProgressView().controlSize(.small)
                }
            }

            if let status = model.status {
                if status.running {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TUNNEL DATA")
                            .font(.caption2.weight(.semibold))
                            .tracking(1)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            TrafficValue(title: "Received", symbol: "arrow.down", bytes: status.traffic?.received)
                            Divider().frame(height: 44)
                            TrafficValue(title: "Sent", symbol: "arrow.up", bytes: status.traffic?.sent)
                        }
                        Text(status.traffic == nil ? "Traffic data unavailable" : "Estimated since tunnel restart")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    model.toggleEnabled()
                    panelWindow.window?.orderOut(nil)
                } label: {
                    Label(status.running ? "Stop Tunnel" : "Start Tunnel", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PanelButtonStyle(prominent: true))
                .controlSize(.large)
                .disabled(model.busy || (!status.running && status.activeTunnelID == nil))
            }

            Divider()
            HStack {
                Button {
                    panelWindow.window?.orderOut(nil)
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(PanelButtonStyle())
            .font(.callout)
        }
        .padding(18)
        .frame(width: 320)
        .background(MenuPanelWindowReader(reference: panelWindow))
        .onAppear { model.refresh() }
    }

    private var statusColor: Color {
        switch model.status?.health ?? .stopped {
        case .active: return .green
        case .running: return .orange
        case .stopped: return .secondary
        }
    }
}

private struct TrafficValue: View {
    let title: String
    let symbol: String
    let bytes: Int64?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                .font(.system(size: 23, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct PanelButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        HoverLabel(configuration: configuration, prominent: prominent)
    }

    private struct HoverLabel: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 10)
                .padding(.vertical, prominent ? 10 : 6)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: prominent ? 8 : 6)
                        .fill(backgroundColor)
                }
                .contentShape(RoundedRectangle(cornerRadius: prominent ? 8 : 6))
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovering = $0 }
        }

        private var backgroundColor: Color {
            let highlighted = hovering && isEnabled
            if prominent {
                return Color.accentColor.opacity(configuration.isPressed ? 0.7 : highlighted ? 1 : 0.85)
            }
            return Color.primary.opacity(configuration.isPressed ? 0.16 : highlighted ? 0.08 : 0)
        }
    }
}

/// Keep a weak reference to this panel so opening Settings dismisses only it.
private final class MenuPanelWindow {
    weak var window: NSWindow?
}

private struct MenuPanelWindowReader: NSViewRepresentable {
    let reference: MenuPanelWindow

    func makeNSView(context: Context) -> WindowView {
        WindowView(reference: reference)
    }

    func updateNSView(_ nsView: WindowView, context: Context) {}

    final class WindowView: NSView {
        let reference: MenuPanelWindow

        init(reference: MenuPanelWindow) {
            self.reference = reference
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reference.window = window
        }
    }
}
