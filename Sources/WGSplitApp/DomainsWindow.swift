import SwiftUI
import WGSplitKit

struct DomainsWindow: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var patterns: [String] = []
    @State private var draft = ""
    @State private var loaded = false

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
        VStack(alignment: .leading, spacing: 12) {
            Text("Routed domains")
                .font(.headline)
            Text("These go through the tunnel. Everything else goes direct.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
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
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove \(pattern)")
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 160)

            VStack(alignment: .leading, spacing: 4) {
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
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    model.setRules(patterns)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420, height: 380)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            model.refresh()
            patterns = (model.status?.rules ?? []).map(\.pattern)
        }
    }

    private func add() {
        guard canAdd else { return }
        patterns.append(draft.trimmingCharacters(in: .whitespaces).lowercased())
        draft = ""
    }

    private func explain(_ pattern: String) -> String {
        guard pattern.hasPrefix("*.") else { return "exact match only" }
        let base = String(pattern.dropFirst(2))
        return "\(base) and all subdomains"
    }
}
