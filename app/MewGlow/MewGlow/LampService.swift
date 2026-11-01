import Foundation

enum LampServiceError: Error {
    case notConnected
    case sendFailed
}

final class LampService {

    static let host = "172.20.10.4"
    static let port = 80

    private let session: URLSession

    private var baseURL: String {
        "http://\(Self.host):\(Self.port)"
    }

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 6
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
    }

    func connect() async throws {
        guard let url = URL(string: "\(baseURL)/ping") else {
            throw LampServiceError.notConnected
        }

        do {
            let (_, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw LampServiceError.notConnected
            }
        } catch {
            throw LampServiceError.notConnected
        }
    }

    func send(command: LampCommand) async throws {
        guard let url = URL(string: "\(baseURL)/command") else {
            throw LampServiceError.sendFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(command)

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw LampServiceError.sendFailed
            }
        } catch {
            throw LampServiceError.sendFailed
        }
    }

    func listenForStatus() async {
    }
}
