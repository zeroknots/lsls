import Foundation

enum PlexConnectionStatus: Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

@MainActor
@Observable
final class PlexConnectionState {
    let apiClient = PlexAPIClient()
    @ObservationIgnored private(set) lazy var auth = PlexAuth(apiClient: apiClient)

    var connectionStatus: PlexConnectionStatus = .disconnected
    var authToken: String?
    var availableServers: [PlexServer] = []
    var selectedServer: PlexServer?
    var musicLibraries: [PlexLibrarySection] = []
    var selectedLibrary: PlexLibrarySection?

    /// Unique server names from all discovered connections
    var uniqueServerNames: [String] {
        var seen = Set<String>()
        return availableServers.compactMap { server in
            guard !seen.contains(server.name) else { return nil }
            seen.insert(server.name)
            return server.name
        }
    }

    var isAuthenticated: Bool { authToken != nil }
    var isConnected: Bool {
        if case .connected = connectionStatus { return true }
        return false
    }

    init() {
        authToken = UserDefaults.standard.string(forKey: "PlexAuthToken")
        if let serversData = UserDefaults.standard.data(forKey: "PlexAvailableServers"),
           let servers = try? JSONDecoder().decode([PlexServer].self, from: serversData) {
            availableServers = servers
        }
        if let serverData = UserDefaults.standard.data(forKey: "PlexSelectedServer"),
           let server = try? JSONDecoder().decode(PlexServer.self, from: serverData) {
            selectedServer = server
            connectionStatus = .connected
        }
        if let librariesData = UserDefaults.standard.data(forKey: "PlexMusicLibraries"),
           let libraries = try? JSONDecoder().decode([PlexLibrarySection].self, from: librariesData) {
            musicLibraries = libraries
        }
        if let libraryData = UserDefaults.standard.data(forKey: "PlexSelectedLibrary"),
           let library = try? JSONDecoder().decode(PlexLibrarySection.self, from: libraryData) {
            selectedLibrary = library
        }
    }

    func saveState() {
        UserDefaults.standard.set(authToken, forKey: "PlexAuthToken")
        if let data = try? JSONEncoder().encode(availableServers) {
            UserDefaults.standard.set(data, forKey: "PlexAvailableServers")
        }
        if let server = selectedServer, let data = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(data, forKey: "PlexSelectedServer")
        }
        if let data = try? JSONEncoder().encode(musicLibraries) {
            UserDefaults.standard.set(data, forKey: "PlexMusicLibraries")
        }
        if let library = selectedLibrary, let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "PlexSelectedLibrary")
        }
    }

    func disconnect() {
        authToken = nil
        availableServers = []
        selectedServer = nil
        selectedLibrary = nil
        musicLibraries = []
        connectionStatus = .disconnected
        for key in ["PlexAuthToken", "PlexAvailableServers", "PlexSelectedServer",
                     "PlexMusicLibraries", "PlexSelectedLibrary"] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func connect(token: String, servers: [PlexServer]? = nil) async {
        authToken = token
        connectionStatus = .connecting
        do {
            let discoveredServers = try await {
                if let servers, !servers.isEmpty { return servers }
                return try await auth.discoverServers(token: token)
            }()
            availableServers = discoveredServers
            guard !discoveredServers.isEmpty else {
                connectionStatus = .error("No servers found")
                return
            }

            await connectToFirstReachable(from: discoveredServers)
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }

    func switchServer(named name: String) async {
        let candidates = availableServers.filter { $0.name == name }
        guard !candidates.isEmpty else { return }
        connectionStatus = .connecting
        await connectToFirstReachable(from: candidates)
    }

    private func connectToFirstReachable(from servers: [PlexServer]) async {
        var lastError: Error?
        for server in servers {
            do {
                let libraries = try await auth.getMusicLibraries(server: server)
                selectedServer = server
                musicLibraries = libraries
                selectedLibrary = libraries.first
                connectionStatus = .connected
                saveState()
                return
            } catch {
                lastError = error
            }
        }
        connectionStatus = .error(lastError?.localizedDescription ?? "Could not connect to any server")
    }
}
