import SwiftUI

struct PlexSettingsView: View {
    @Environment(PlexConnectionState.self) private var plexState
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var servers: [PlexServer] = []
    @State private var showServerPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Plex Music")
                        .font(.title.bold())
                    Text("Stream music from your Plex Media Server")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                if plexState.isConnected {
                    // Connected state - show server info and disconnect
                    connectedView
                } else if isAuthenticating {
                    // Authenticating state
                    authenticatingView
                } else {
                    // Disconnected - show connect button
                    disconnectedView
                }

                if let error = authError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Plex Settings")
    }

    private var connectedView: some View {
        VStack(spacing: 16) {
            // Server info card
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    if let server = plexState.selectedServer {
                        LabeledContent("Server", value: server.name)
                        LabeledContent("Address", value: "\(server.host):\(server.port)")
                    }

                    if let library = plexState.selectedLibrary {
                        LabeledContent("Library", value: library.title)
                    }

                    // Library picker if multiple libraries available
                    if plexState.musicLibraries.count > 1 {
                        Picker("Music Library", selection: Binding(
                            get: { plexState.selectedLibrary },
                            set: { newValue in
                                plexState.selectedLibrary = newValue
                                plexState.saveState()
                            }
                        )) {
                            ForEach(plexState.musicLibraries) { library in
                                Text(library.title).tag(Optional(library))
                            }
                        }
                    }
                }
                .padding(4)
            } label: {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            // Server picker (if multiple servers found)
            if servers.count > 1 {
                Picker("Server", selection: Binding(
                    get: { plexState.selectedServer },
                    set: { newValue in
                        if let newServer = newValue {
                            Task {
                                plexState.selectedServer = newServer
                                // Reload libraries for new server
                                let libraries = try? await plexState.auth.getMusicLibraries(
                                    server: newServer)
                                plexState.musicLibraries = libraries ?? []
                                plexState.selectedLibrary = plexState.musicLibraries.first
                                plexState.saveState()
                            }
                        }
                    }
                )) {
                    ForEach(servers) { server in
                        Text(server.name).tag(Optional(server))
                    }
                }
            }

            Button("Disconnect") {
                plexState.disconnect()
                servers = []
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.red)
        }
    }

    private var authenticatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Waiting for authentication...")
                .foregroundStyle(.secondary)
            Text("A browser window has opened. Please sign in to Plex.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: 16) {
            Button {
                startAuth()
            } label: {
                Label("Connect to Plex", systemImage: "link")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func startAuth() {
        isAuthenticating = true
        authError = nil

        Task {
            do {
                let pin = try await plexState.auth.requestPin()
                plexState.auth.openAuthPage(pin: pin)
                let token = try await plexState.auth.pollForToken(pinId: pin.id)

                // Discover servers
                let discoveredServers = try await plexState.auth.discoverServers(token: token)
                servers = discoveredServers

                await plexState.connect(token: token)
                isAuthenticating = false
            } catch {
                authError = error.localizedDescription
                isAuthenticating = false
            }
        }
    }
}
