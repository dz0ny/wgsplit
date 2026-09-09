import Foundation

public enum ImportError: Error, Equatable {
    case noConfigsFound
}

public enum TunnelImporter {
    public static func importTunnels(fromZip url: URL) throws -> [Tunnel] {
        let entries = try ZipReader.confEntries(at: url)
        guard !entries.isEmpty else { throw ImportError.noConfigsFound }
        return try entries.sorted { $0.key < $1.key }.map { name, text in
            try WGQuickParser.parse(text, name: displayName(for: name))
        }
    }

    static func displayName(for entryPath: String) -> String {
        URL(fileURLWithPath: entryPath).deletingPathExtension().lastPathComponent
    }
}
