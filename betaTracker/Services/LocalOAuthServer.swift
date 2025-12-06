//
//  LocalOAuthServer.swift
//  betaTracker
//
//  Created by MEWP (Matthew Phelps) on 06/12/2025.
//

import Foundation

/// Simple local HTTP server to catch OAuth callbacks
class LocalOAuthServer {
    private var listener: CFSocket?
    private let port: UInt16
    private let onCodeReceived: (String) -> Void

    init(port: UInt16, onCodeReceived: @escaping (String) -> Void) {
        self.port = port
        self.onCodeReceived = onCodeReceived
    }

    func start() {
        let context = Unmanaged.passRetained(self).toOpaque()
        var socketContext = CFSocketContext(
            version: 0,
            info: context,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        listener = CFSocketCreate(
            kCFAllocatorDefault,
            PF_INET,
            SOCK_STREAM,
            IPPROTO_TCP,
            CFSocketCallBackType.acceptCallBack.rawValue,
            { socket, callbackType, address, data, info in
                guard let info = info else { return }
                let server = Unmanaged<LocalOAuthServer>.fromOpaque(info).takeUnretainedValue()
                server.handleConnection(socket: data)
            },
            &socketContext
        )

        guard let listener = listener else {
            print("ERROR: Failed to create socket")
            return
        }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian

        let addressData = withUnsafePointer(to: &addr) {
            Data(bytes: $0, count: MemoryLayout<sockaddr_in>.size)
        }

        guard CFSocketSetAddress(listener, addressData as CFData) == .success else {
            print("ERROR: Failed to bind socket to port \(port)")
            return
        }

        let runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, listener, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        print("DEBUG: Local server listening on port \(port)")
    }

    private func handleConnection(socket: UnsafeRawPointer?) {
        guard let socket = socket else { return }
        let nativeSocket = socket.load(as: CFSocketNativeHandle.self)

        // Read the HTTP request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(nativeSocket, &buffer, buffer.count, 0)

        guard bytesRead > 0 else {
            close(nativeSocket)
            return
        }

        let requestString = String(bytes: buffer[..<bytesRead], encoding: .utf8) ?? ""
        print("DEBUG: Received HTTP request")

        // Extract the code parameter from GET request
        if let codeRange = requestString.range(of: "GET /callback\\?.*code=([^&\\s]+)", options: .regularExpression) {
            let matchString = String(requestString[codeRange])
            if let code = matchString.components(separatedBy: "code=").last?.components(separatedBy: "&").first {
                print("DEBUG: Extracted authorization code")

                // Send success response
                let response = """
                HTTP/1.1 200 OK\r
                Content-Type: text/html\r
                \r
                <html>
                <head><title>Authorization Successful</title></head>
                <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
                <h1>✓ Authorization Successful!</h1>
                <p>You can close this window and return to the app.</p>
                <script>window.close();</script>
                </body>
                </html>
                """

                send(nativeSocket, response, response.utf8.count, 0)

                // Call the callback with the code
                DispatchQueue.main.async {
                    self.onCodeReceived(code)
                }
            }
        }

        close(nativeSocket)
    }

    func stop() {
        if let listener = listener {
            CFSocketInvalidate(listener)
            self.listener = nil
            print("DEBUG: Local server stopped")
        }
    }

    deinit {
        stop()
    }
}
