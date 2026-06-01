import SwiftUI

struct MainTabView: View {
    @Environment(AuthManager.self) var authManager
    @State private var viewModel = GamesViewModel()
    @State private var gameToPlay: GameInfo?
    @State private var sessionToResume: ActiveSessionInfo? = nil
    @State private var directSessionToResume: SessionInfo? = nil
    @State private var selectingStoreForGame: GameInfo? = nil

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView(
                    onPlay: handlePlayGame,
                    onResume: { rs in
                        directSessionToResume = rs.session
                        sessionToResume = nil
                        gameToPlay = rs.game
                    },
                    onResumeActive: { activeSession, game in
                        sessionToResume = activeSession
                        directSessionToResume = nil
                        gameToPlay = game
                    }
                )
            }
            Tab("Library", systemImage: "books.vertical.fill") {
                LibraryView(games: viewModel.libraryGames, onPlay: handlePlayGame)
            }
            Tab("Store", systemImage: "bag.fill") {
                StoreView(games: viewModel.mainGames, onPlay: handlePlayGame)
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .environment(viewModel)
        .task { await viewModel.load(authManager: authManager) }
        .onChange(of: viewModel.streamSettings) { viewModel.saveSettings() }
        .onChange(of: gameToPlay) { _, new in
            if new == nil {
                directSessionToResume = nil
                Task { await viewModel.refreshActiveSessions(authManager: authManager) }
            }
        }
        .sheet(item: $selectingStoreForGame) { game in
            StoreSelectorSheet(
                game: game,
                onSelect: { variant, remember in
                    if remember {
                        viewModel.setPreferredStore(gameId: game.id, variantId: variant.id)
                    }
                    var g = game
                    if let idx = g.variants.firstIndex(where: { $0.id == variant.id }) {
                        let pref = g.variants.remove(at: idx)
                        g.variants.insert(pref, at: 0)
                    }
                    gameToPlay = g
                    selectingStoreForGame = nil
                },
                onCancel: {
                    selectingStoreForGame = nil
                }
            )
        }
        .fullScreenCover(item: $gameToPlay) { game in
            StreamView(
                game: game,
                settings: viewModel.streamSettings,
                existingSession: sessionToResume,
                directSession: directSessionToResume,
                onDismiss: {
                    gameToPlay = nil
                    sessionToResume = nil
                },
                onLeave: { leftGame, session in
                    viewModel.resumableSession = ResumableSession(
                        game: leftGame,
                        session: session,
                        leftAt: Date()
                    )
                }
            )
            .environment(authManager)
            .environment(viewModel)
        }
    }

    private func handlePlayGame(_ game: GameInfo) {
        sessionToResume = viewModel.activeSessions.first { session in
            game.variants.contains { v in
                guard let appId = v.appId, let sessionAppId = session.appId else { return false }
                return appId == sessionAppId
            }
        }
        directSessionToResume = nil

        if game.variants.count > 1 && !viewModel.hasPreferredStore(for: game) {
            selectingStoreForGame = game
        } else {
            gameToPlay = viewModel.gameWithPreferredStore(game)
        }
    }
}
