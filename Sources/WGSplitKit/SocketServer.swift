import Foundation

/// Blocking Unix socket server: one connection at a time, one
/// newline-delimited request per connection. The daemon does very little
/// work per request, so concurrency would be complexity without benefit.
public final class SocketServer {
    private let path: String
    private let ownerGID: gid_t?
    private let handler: (Data) -> Data

    /// - Parameter ownerGID: group given rw access (gid 20 = `staff` on macOS,
    ///   which the console user belongs to). Nil leaves ownership alone, which
    ///   is what tests want since they do not run as root.
    public init(path: String, ownerGID: gid_t? = nil, handler: @escaping (Data) -> Data) {
        self.path = path
        self.ownerGID = ownerGID
        self.handler = handler
    }

    public func bindAndListen() throws -> Int32 {
        unlink(path)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.EADDRNOTAVAIL) }

        var addr = UnixSocket.address(for: path)
        guard UnixSocket.withSockaddr(&addr, { bind(fd, $0, $1) }) == 0 else {
            close(fd)
            throw POSIXError(.EADDRINUSE)
        }
        if let gid = ownerGID { chown(path, 0, gid) }
        chmod(path, 0o660)
        guard listen(fd, 8) == 0 else {
            close(fd)
            throw POSIXError(.ECONNREFUSED)
        }
        return fd
    }

    public func serveOnce(_ listenFD: Int32) {
        let client = accept(listenFD, nil, nil)
        guard client >= 0 else { return }
        defer { close(client) }
        guard let request = UnixSocket.readFrame(client) else { return }
        UnixSocket.writeAll(client, handler(request))
    }

    public func run() throws {
        let fd = try bindAndListen()
        defer { close(fd); unlink(path) }
        while true { serveOnce(fd) }
    }
}
