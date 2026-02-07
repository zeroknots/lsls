import SwiftUI

struct PlexSettingsView: View {
    @Environment(PlexConnectionState.self) private var plexState
    @Environment(\.themeColors) private var colors
    @Environment(\.theme) private var theme
    @State private var isAuthenticating = false
    @State private var authError: String?
    @State private var servers: [PlexServer] = []

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.sectionSpacing) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 48))
                        .foregroundStyle(colors.textTertiary)
                    Text("Plex Music")
                        .font(.system(size: theme.typography.titleSize, weight: .bold))
                        .foregroundStyle(colors.textPrimary)
                    Text("Stream music from your Plex Media Server")
                        .font(.system(size: theme.typography.captionSize))
                        .foregroundStyle(colors.textSecondary)
                }
                .padding(.top, 40)

                if plexState.isConnected {
                    connectedView
                } else if isAuthenticating {
                    authenticatingView
                } else {
                    disconnectedView
                }

                if let error = authError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.system(size: theme.typography.captionSize))
                }
            }
            .padding(theme.spacing.contentPadding)
            .frame(maxWidth: .infinity)
        }
        .background(colors.background)
        .navigationTitle("Plex Settings")
    }

    private var connectedView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.system(size: theme.typography.bodySize, weight: .semibold))
                    .foregroundStyle(.green)

                if let server = plexState.selectedServer {
                    LabeledContent {
                        Text(server.name)
                            .foregroundStyle(colors.textPrimary)
                    } label: {
                        Text("Server")
                            .foregroundStyle(colors.textSecondary)
                    }
                    .font(.system(size: theme.typography.bodySize))

                    LabeledContent {
                        Text("\(server.host):\(server.port)")
                            .foregroundStyle(colors.textPrimary)
                    } label: {
                        Text("Address")
                            .foregroundStyle(colors.textSecondary)
                    }
                    .font(.system(size: theme.typography.bodySize))
                }

                if let library = plexState.selectedLibrary {
                    LabeledContent {
                        Text(library.title)
                            .foregroundStyle(colors.textPrimary)
                    } label: {
                        Text("Library")
                            .foregroundStyle(colors.textSecondary)
                    }
                    .font(.system(size: theme.typography.bodySize))
                }

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
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: theme.shapes.cardRadius)
                    .fill(colors.surface)
            )

            if servers.count > 1 {
                Picker("Server", selection: Binding(
                    get: { plexState.selectedServer },
                    set: { newValue in
                        if let newServer = newValue {
                            Task {
                                plexState.selectedServer = newServer
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
            .buttonStyle(AccentOutlineButtonStyle())
        }
    }

    private var authenticatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Waiting for authentication...")
                .font(.system(size: theme.typography.bodySize))
                .foregroundStyle(colors.textSecondary)
            Text("A browser window has opened. Please sign in to Plex.")
                .font(.system(size: theme.typography.captionSize))
                .foregroundStyle(colors.textTertiary)
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
            .buttonStyle(AccentFilledButtonStyle())
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
