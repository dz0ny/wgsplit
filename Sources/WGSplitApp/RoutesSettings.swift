import SwiftUI
import WGSplitKit

struct RoutesSettings: View {
    @ObservedObject var model: AppModel

    @State private var patterns: [String] = []
    @State private var draft = ""
    @State private var dirty = false
    @State private var listHeight: CGFloat = 1

    private var draftError: String? {
        let trimmed = draft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if patterns.contains(trimmed.lowercased()) { return "Already in the list." }
        do {
            _ = try RuleCompiler.compile([Rule(pattern: trimmed)])
            return nil
        } catch RuleError.tooBroad {
            return "Too broad — needs at least two labels, like *.niteo.co."
        } catch {
            return "Not a valid pattern."
        }
    }

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty && draftError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsNote(text: "Choose which domains use the active tunnel. Other traffic uses your direct connection.")

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if patterns.isEmpty {
                        Text("No domains yet — nothing is being routed.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(patterns, id: \.self) { pattern in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pattern).font(.body.monospaced())
                                Text(explain(pattern))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                patterns.removeAll { $0 == pattern }
                                dirty = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove \(pattern)")
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: RouteListHeight.self, value: geometry.size.height)
                    }
                }
            }
            .frame(height: min(listHeight, 320))
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .onPreferenceChange(RouteListHeight.self) { listHeight = $0 }

            SettingsSection(title: "Add a Domain") {
                SettingsNote(text: "Use example.com for one domain, or *.example.com to include all its subdomains.")
                HStack {
                    TextField("*.example.com", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { add() }
                    Button("Add", action: add).disabled(!canAdd)
                }
                if let draftError {
                    Label(draftError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            HStack {
                Text("Select Save to apply your changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Revert") { loadRules() }
                    .disabled(!dirty || model.busy)
                Button("Save") {
                    model.setRules(patterns)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!dirty || model.busy || model.status == nil)
            }
        }
        .padding(.vertical, 12)
        .disabled(model.status == nil || model.busy)
        .onAppear { if !dirty { loadRules() } }
        .onChange(of: model.status?.rules) { _, rules in
            let saved = (rules ?? []).map(\.pattern)
            if saved == patterns { dirty = false }
            if !dirty { patterns = saved }
        }
    }

    private func loadRules() {
        patterns = (model.status?.rules ?? []).map(\.pattern)
        draft = ""
        dirty = false
    }

    private func add() {
        guard canAdd else { return }
        patterns.append(draft.trimmingCharacters(in: .whitespaces).lowercased())
        draft = ""
        dirty = true
    }

    private func explain(_ pattern: String) -> String {
        guard pattern.hasPrefix("*.") else { return "exact match only" }
        let base = String(pattern.dropFirst(2))
        return "\(base) and all subdomains"
    }
}

private struct RouteListHeight: PreferenceKey {
    static var defaultValue: CGFloat = 1
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
