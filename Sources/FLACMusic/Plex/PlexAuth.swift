import AppKit
import Foundation

// MARK: - PlexAuthError

enum PlexAuthError: Error, LocalizedError {
    case timeout
    case noPinCode
    case noServersFound

    var errorDescription: String? {
        switch self {
        case .timeout: "Authentication timed out"
        case .noPinCode: "Failed to get PIN code"
        case .noServersFound: "No Plex servers found"
        }
    }
}

// MARK: - PlexAuth

@MainActor
final class PlexAuth {

    // MARK: - Properties

    private let apiClient: PlexAPIClient
    private let clientIdentifier: String

    // MARK: - Initialization

    init(apiClient: PlexAPIClient) {
        self.apiClient = apiClient

        let key = "PlexClientIdentifier"
        if let existing = UserDefaults.standard.string(forKey: key) {
            self.clientIdentifier = existing
        } else {
            let generated = UUID().uuidString
            UserDefaults.standard.set(generated, forKey: key)
            self.clientIdentifier = generated
        }
    }

    // MARK: - PIN Auth Flow

    func requestPin() async throws -> PlexPin {
        guard let url = URL(string: "https://plex.tv/api/v2/pins") else {
            throw PlexAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(PlexAPIClient.productName, forHTTPHeaderField: "X-Plex-Product")
        request.setValue(PlexAPIClient.productVersion, forHTTPHeaderField: "X-Plex-Version")

        let bodyString = "strong=true&X-Plex-Product=FLACMusic&X-Plex-Client-Identifier=\(clientIdentifier)"
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlexAPIError.httpError(statusCode: statusCode, data: data)
        }

        let pin = try JSONDecoder().decode(PlexPin.self, from: data)

        guard !pin.code.isEmpty else {
            throw PlexAuthError.noPinCode
        }

        return pin
    }

    func openAuthPage(pin: PlexPin) {
        let urlString = "https://app.plex.tv/auth#?clientID=\(clientIdentifier)&code=\(pin.code)&context%5Bdevice%5D%5Bproduct%5D=FLACMusic"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func pollForToken(pinId: Int) async throws -> String {
        guard let url = URL(string: "https://plex.tv/api/v2/pins/\(pinId)") else {
            throw PlexAPIError.invalidURL
        }

        let maxPolls = 150
        let pollInterval: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds

        for _ in 0..<maxPolls {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
            request.setValue(PlexAPIClient.productName, forHTTPHeaderField: "X-Plex-Product")
            request.setValue(PlexAPIClient.productVersion, forHTTPHeaderField: "X-Plex-Version")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw PlexAPIError.httpError(statusCode: statusCode, data: data)
            }

            let pin = try JSONDecoder().decode(PlexPin.self, from: data)

            if let token = pin.authToken, !token.isEmpty {
                return token
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        throw PlexAuthError.timeout
    }

    // MARK: - Server Discovery

    func discoverServers(token: String) async throws -> [PlexServer] {
        guard let url = URL(string: "https://plex.tv/api/v2/resources?includeHttps=1&includeRelay=0") else {
            throw PlexAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        request.setValue(PlexAPIClient.productName, forHTTPHeaderField: "X-Plex-Product")
        request.setValue(PlexAPIClient.productVersion, forHTTPHeaderField: "X-Plex-Version")
        request.setValue(token, forHTTPHeaderField: "X-Plex-Token")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw PlexAPIError.httpError(statusCode: statusCode, data: data)
        }

        let resources = try JSONDecoder().decode([PlexResource].self, from: data)

        let serverResources = resources.filter { $0.provides.contains("server") }

        let servers: [PlexServer] = serverResources.compactMap { resource in
            guard let connection = bestConnection(from: resource.connections) else {
                return nil
            }
            return serverFromConnection(connection, name: resource.name, token: token)
        }

        guard !servers.isEmpty else {
            throw PlexAuthError.noServersFound
        }

        return servers
    }

    func getMusicLibraries(server: PlexServer) async throws -> [PlexLibrarySection] {
        let sections = try await apiClient.getLibrarySections(server: server)
        return sections.filter { $0.type == "artist" }
    }

    // MARK: - Private Helpers

    private func bestConnection(from connections: [PlexConnection]) -> PlexConnection? {
        // Prefer non-local HTTPS connections
        if let remote = connections.first(where: { !$0.local && $0.connectionProtocol == "https" }) {
            return remote
        }
        // Fall back to any HTTPS connection
        if let https = connections.first(where: { $0.connectionProtocol == "https" }) {
            return https
        }
        // Fall back to any non-local connection
        if let remote = connections.first(where: { !$0.local }) {
            return remote
        }
        // Fall back to first available
        return connections.first
    }

    private func serverFromConnection(
        _ connection: PlexConnection,
        name: String,
        token: String
    ) -> PlexServer? {
        guard let urlComponents = URLComponents(string: connection.uri) else {
            return nil
        }

        let scheme = urlComponents.scheme ?? connection.connectionProtocol
        let host = urlComponents.host ?? ""
        let port = urlComponents.port ?? (scheme == "https" ? 443 : 32400)

        guard !host.isEmpty else { return nil }

        return PlexServer(
            name: name,
            host: host,
            port: port,
            scheme: scheme,
            token: token
        )
    }
}
