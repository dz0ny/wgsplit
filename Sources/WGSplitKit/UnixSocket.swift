import Foundation

/// Shared plumbing for the control socket. Kept in one place because
/// sockaddr_un's fixed-size tuple is easy to get subtly wrong.
public enum UnixSocket {
    public static func address(for path: String) -> sockaddr_un {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        withUnsafeMutableBytes(of: &addr.sun_path) { raw in
            precondition(bytes.count < raw.count, "socket path too long: \(path)")
            raw.copyBytes(from: bytes)
            raw[bytes.count] = 0
        }
        return addr
    }

    public static func withSockaddr<T>(_ addr: inout sockaddr_un,
                                       _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, len) }
        }
    }

    /// Reads one newline-terminated frame. Returns nil if the peer closed first.
    public static func readFrame(_ fd: Int32) -> Data? {
        var out = Data()
        var byte: UInt8 = 0
        while read(fd, &byte, 1) == 1 {
            if byte == 0x0A { return out }
            out.append(byte)
        }
        return out.isEmpty ? nil : out
    }

    @discardableResult
    public static func writeAll(_ fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { buf -> Bool in
            var sent = 0
            while sent < buf.count {
                let n = write(fd, buf.baseAddress!.advanced(by: sent), buf.count - sent)
                if n <= 0 { return false }
                sent += n
            }
            return true
        }
    }
}
