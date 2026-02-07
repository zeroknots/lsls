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
    var selectedServer: PlexServer?
    var musicLibraries: [PlexLibrarySection] = []
    var selectedLibrary: PlexLibrarySection?

    var isAuthenticated: Bool { authToken != nil }
    var isConnected: Bool {
        if case .connected = connectionStatus { return true }
        return false
    }

    init() {
        // Load saved auth token from UserDefaults
        authToken = UserDefaults.standard.string(forKey: "PlexAuthToken")
        if let serverData = UserDefaults.standard.data(forKey: "PlexSelectedServer"),
           let server = try? JSONDecoder().decode(PlexServer.self, from: serverData) {
            selectedServer = server
            connectionStatus = .connected
        }
        if let libraryData = UserDefaults.standard.data(forKey: "PlexSelectedLibrary"),
           let library = try? JSONDecoder().decode(PlexLibrarySection.self, from: libraryData) {
            selectedLibrary = library
        }
    }

    func saveState() {
        UserDefaults.standard.set(authToken, forKey: "PlexAuthToken")
        if let server = selectedServer, let data = try? JSONEncoder().encode(server) {
            UserDefaults.standard.set(data, forKey: "PlexSelectedServer")
        }
        if let library = selectedLibrary, let data = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(data, forKey: "PlexSelectedLibrary")
        }
    }

    func disconnect() {
        authToken = nil
        selectedServer = nil
        selectedLibrary = nil
        musicLibraries = []
        connectionStatus = .disconnected
        UserDefaults.standard.removeObject(forKey: "PlexAuthToken")
        UserDefaults.standard.removeObject(forKey: "PlexSelectedServer")
        UserDefaults.standard.removeObject(forKey: "PlexSelectedLibrary")
    }

    func connect(token: String) async {
        authToken = token
        connectionStatus = .connecting
        do {
            let servers = try await auth.discoverServers(token: token)
            guard let server = servers.first else {
                connectionStatus = .error("No servers found")
                return
            }
            selectedServer = server
            let libraries = try await auth.getMusicLibraries(server: server)
            musicLibraries = libraries
            selectedLibrary = libraries.first
            connectionStatus = .connected
            saveState()
        } catch {
            connectionStatus = .error(error.localizedDescription)
        }
    }
}
