import Testing
import Foundation
import UIKit
@testable import KhmNow

@Suite("UI Component and ViewModel Tests", .serialized)
@MainActor
struct UIComponentTests {
    init() {
        // Clear User Defaults for clean runs
        UserDefaults.standard.removeObject(forKey: "gfn.favoriteIds")
        UserDefaults.standard.removeObject(forKey: "gfn.preferredStores")
        UserDefaults.standard.removeObject(forKey: "gfn.recentlyPlayed")
        UserDefaults.standard.removeObject(forKey: "gfn.streamSettings")
    }

    @Test func testGamesViewModelInitialState() {
        UserDefaults.standard.removeObject(forKey: "gfn.favoriteIds")
        UserDefaults.standard.removeObject(forKey: "gfn.preferredStores")
        UserDefaults.standard.removeObject(forKey: "gfn.recentlyPlayed")
        UserDefaults.standard.removeObject(forKey: "gfn.streamSettings")
        let vm = GamesViewModel()
        #expect(vm.mainGames.isEmpty)
        #expect(vm.libraryGames.isEmpty)
        #expect(vm.favoriteIds.isEmpty)
        #expect(vm.recentlyPlayedIds.isEmpty)
        #expect(vm.isLoading == false)
    }

    @Test func testGamesViewModelToggleFavorite() {
        let vm = GamesViewModel()
        #expect(!vm.isFavorite("123"))
        
        vm.toggleFavorite("123")
        #expect(vm.isFavorite("123"))
        #expect(vm.favoriteIds.contains("123"))

        vm.toggleFavorite("123")
        #expect(!vm.isFavorite("123"))
    }

    @Test func testGamesViewModelRecentlyPlayed() {
        let vm = GamesViewModel()
        let game = GameInfo(id: "123", title: "Game 123", boxArtUrl: nil, heroBannerUrl: nil, isInLibrary: false, variants: [])
        
        vm.recordPlayed(game)
        #expect(vm.recentlyPlayedIds.first == "123")
        #expect(vm.recentlyPlayedIds.count == 1)
    }

    @Test func testGamesViewModelPreferredStore() {
        let vm = GamesViewModel()
        let variant = GameVariant(id: "v123", appStore: "STEAM", appId: nil)
        let game = GameInfo(id: "g123", title: "Game", boxArtUrl: nil, heroBannerUrl: nil, isInLibrary: false, variants: [variant])

        #expect(!vm.hasPreferredStore(for: game))
        #expect(vm.preferredVariantId(for: game) == "v123")

        vm.setPreferredStore(gameId: "g123", variantId: "v123")
        #expect(vm.hasPreferredStore(for: game))
        #expect(vm.preferredVariantId(for: game) == "v123")
    }

    @Test func testGamesViewModelResolutionsAndFPS() {
        let vm = GamesViewModel()
        
        // Empty subscription returns fallback
        #expect(vm.availableResolutions == ["1280x720", "1920x1080"])
        
        let entitled = [
            EntitledResolution(widthInPixels: 1920, heightInPixels: 1080, framesPerSecond: 60),
            EntitledResolution(widthInPixels: 1280, heightInPixels: 720, framesPerSecond: 120),
            EntitledResolution(widthInPixels: 1920, heightInPixels: 1080, framesPerSecond: 30)
        ]
        let sub = SubscriptionInfo(
            membershipTier: "Ultimate",
            isUnlimited: true,
            remainingMinutes: nil,
            totalMinutes: nil,
            entitledResolutions: entitled
        )
        vm.subscription = sub
        
        // Ordered resolutions
        #expect(vm.availableResolutions == ["1280x720", "1920x1080"])
        
        vm.streamSettings.resolution = "1920x1080"
        #expect(vm.availableFps.contains(30))
        #expect(vm.availableFps.contains(60))
    }

    @Test func testExpiredSessionIdsBlocklist() {
        // Clear defaults
        UserDefaults.standard.removeObject(forKey: "gfn.expiredSessionIds")
        UserDefaults.standard.removeObject(forKey: "gfn.resumableSession")
        
        let vm = GamesViewModel()
        #expect(vm.expiredSessionIds.isEmpty)
        
        // 1. Mark session expired
        vm.markSessionExpired("session-1")
        #expect(vm.expiredSessionIds.contains("session-1"))
        
        // 2. Check persistence in new instance
        let vm2 = GamesViewModel()
        #expect(vm2.expiredSessionIds.contains("session-1"))
        
        // 3. Test that loading a blocklisted resumable session discards it
        let mockGame = GameInfo(id: "game1", title: "Game 1", boxArtUrl: nil, heroBannerUrl: nil, isInLibrary: false, variants: [])
        let mockSession = SessionInfo(
            sessionId: "session-1",
            status: 2,
            zone: "zone",
            streamingBaseUrl: "http://base",
            serverIp: "1.2.3.4",
            signalingServer: "signaling",
            signalingUrl: "http://signaling",
            gpuType: nil,
            queuePosition: nil,
            seatSetupStep: nil,
            iceServers: [],
            mediaConnectionInfo: nil,
            clientId: "client",
            deviceId: "device",
            adState: nil
        )
        let resumable = ResumableSession(
            game: mockGame,
            session: mockSession,
            leftAtServerTime: Date(),
            gracePeriod: 120
        )
        if let data = try? JSONEncoder().encode(resumable) {
            UserDefaults.standard.set(data, forKey: "gfn.resumableSession")
        }
        
        let vm3 = GamesViewModel()
        // Because "session-1" is in the blocklist, the resumable session should be discarded (nil)
        #expect(vm3.resumableSession == nil)
        
        // 4. Test that clearResumableSession blocklists the session
        let mockSession2 = SessionInfo(
            sessionId: "session-2",
            status: 2,
            zone: "zone",
            streamingBaseUrl: "http://base",
            serverIp: "1.2.3.4",
            signalingServer: "signaling",
            signalingUrl: "http://signaling",
            gpuType: nil,
            queuePosition: nil,
            seatSetupStep: nil,
            iceServers: [],
            mediaConnectionInfo: nil,
            clientId: "client",
            deviceId: "device",
            adState: nil
        )
        vm3.resumableSession = ResumableSession(
            game: mockGame,
            session: mockSession2,
            leftAtServerTime: Date(),
            gracePeriod: 120
        )
        #expect(!vm3.expiredSessionIds.contains("session-2"))
        vm3.clearResumableSession()
        #expect(vm3.resumableSession == nil)
        #expect(vm3.expiredSessionIds.contains("session-2"))
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "gfn.expiredSessionIds")
        UserDefaults.standard.removeObject(forKey: "gfn.resumableSession")
    }

    @Test func testValidateActiveSessionRecreationBug() async throws {
        // Clear defaults
        UserDefaults.standard.removeObject(forKey: "gfn.expiredSessionIds")
        UserDefaults.standard.removeObject(forKey: "gfn.resumableSession")
        KeychainService.isTesting = true
        KeychainService.delete()
        
        let mockURLSession = makeMockSession()
        let vm = GamesViewModel(urlSession: mockURLSession)
        
        // Setup AuthManager using KeychainService
        let tokens = AuthTokens(
            accessToken: "mock-token",
            refreshToken: "r",
            idToken: "mock-token",
            expiresAt: Date().addingTimeInterval(3600),
            clientToken: "ct",
            clientTokenExpiresAt: Date().addingTimeInterval(3600)
        )
        let user = AuthUser(userId: "u", displayName: "D", email: "e", avatarUrl: nil, membershipTier: "Free")
        let provider = LoginProvider(idpId: "idp", code: "code", displayName: "Name", streamingServiceUrl: "https://stream.com", priority: 1)
        let authSession = AuthSession(provider: provider, tokens: tokens, user: user)
        let sessionData = try JSONEncoder().encode(authSession)
        try KeychainService.save(sessionData)
        
        let api = NVIDIAAuthAPI(session: mockURLSession)
        let auth = AuthManager(api: api)
        await auth.initialize()
        #expect(auth.isAuthenticated)
        
        // Mock active game and session
        let mockGame = GameInfo(id: "game1", title: "Game 1", boxArtUrl: nil, heroBannerUrl: nil, isInLibrary: false, variants: [
            GameVariant(id: "var1", appStore: "STEAM", appId: "100")
        ])
        vm.mainGames = [mockGame]
        
        // Mock activeSessions returned by getActiveSessions / URLProtocol
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let responseHeaders = ["Date": "Tue, 02 Jun 2026 01:50:00 GMT"]
            
            if url.absoluteString.contains("/v2/session/session-1") {
                // validateSession
                let json = """
                {
                    "session": {
                        "sessionId": "session-1",
                        "status": 2,
                        "serverIp": "1.2.3.4",
                        "signalingUrl": "http://signaling"
                    }
                }
                """
                return (makeHTTPResponse(url: url, statusCode: 200, headers: responseHeaders), json.data(using: .utf8)!)
            }
            throw URLError(.badURL)
        }
        
        // Setup a resumable session
        vm.resumableSession = ResumableSession(
            game: mockGame,
            session: SessionInfo(
                sessionId: "session-1",
                status: 2,
                zone: "zone",
                streamingBaseUrl: "http://base",
                serverIp: "1.2.3.4",
                signalingServer: "signaling",
                signalingUrl: "http://signaling",
                gpuType: nil,
                queuePosition: nil,
                seatSetupStep: nil,
                iceServers: [],
                mediaConnectionInfo: nil,
                clientId: "client",
                deviceId: "device",
                adState: nil
            ),
            leftAtServerTime: Date(),
            gracePeriod: 120
        )
        
        // We set activeSessions to contain the same session ID
        vm.activeSessions = [
            ActiveSessionInfo(sessionId: "session-1", status: 2, appId: "100", serverIp: "1.2.3.4", signalingUrl: "http://signaling")
        ]
        
        // Clear the resumable session (as if timer expired or terminated)
        #expect(vm.resumableSession != nil)
        vm.clearResumableSession()
        #expect(vm.resumableSession == nil)
        
        // Now call validateActiveSession
        await vm.validateActiveSession(authManager: auth)
        
        // With the blocklist fix, resumableSession should NOT be recreated/restored!
        #expect(vm.resumableSession == nil)
        
        // Clean up
        UserDefaults.standard.removeObject(forKey: "gfn.expiredSessionIds")
        UserDefaults.standard.removeObject(forKey: "gfn.resumableSession")
        KeychainService.delete()
    }
}
