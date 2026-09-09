import Foundation

public enum ControlClientError: Error, Equatable {
    case daemonUnavailable
    case badResponse
}

public struct ControlClient: Sendable {
    private let path: String
    public init(path: String = "/var/run/wgsplit.sock") { self.path = path }

    public func send(_ request: ControlRequest) throws -> ControlResponse {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ControlClientError.daemonUnavailable }
        defer { close(fd) }

        var addr = UnixSocket.address(for: path)
        let connected = UnixSocket.withSockaddr(&addr) { ptr, len in connect(fd, ptr, len) }
        guard connected == 0 else { throw ControlClientError.daemonUnavailable }

        guard UnixSocket.writeAll(fd, try ControlCodec.encode(request)) else {
            throw ControlClientError.daemonUnavailable
        }
        guard let line = UnixSocket.readFrame(fd) else { throw ControlClientError.badResponse }
        return try ControlCodec.decode(ControlResponse.self, from: line)
    }
}
