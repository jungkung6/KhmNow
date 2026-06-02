import Testing
import Foundation
@testable import KhmNow

@Suite("Session Clients Tests", .serialized)
@MainActor
struct SessionClientTests {
    private let mockSession: URLSession

    init() {
        URLProtocol.registerClass(MockURLProtocol.self)
        self.mockSession = makeMockSession()
    }

    @Test func testMESClientFetchVpcId() async throws {
        let client = MESClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString.contains("/v2/serverInfo"))
            let json = """
            {
                "requestStatus": {
                    "serverId": "NP-AMS-08"
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }

        let vpcId = try await client.fetchVpcId(token: "token", base: "https://test.com")
        #expect(vpcId == "NP-AMS-08")
    }

    @Test func testMESClientFetchSubscription() async throws {
        let client = MESClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString.contains("subscriptions"))
            let json = """
            {
                "membershipTier": "ULTIMATE",
                "subType": "UNLIMITED",
                "remainingTimeInMinutes": 100,
                "totalTimeInMinutes": 200,
                "features": {
                    "resolutions": [
                        {
                            "widthInPixels": 1920,
                            "heightInPixels": 1080,
                            "framesPerSecond": 60,
                            "isEntitled": true
                        }
                    ]
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }

        let sub = try await client.fetchSubscription(token: "token", vpcId: "vpc", userId: "user")
        #expect(sub.membershipTier == "ULTIMATE")
        #expect(sub.isUnlimited == true)
        #expect(sub.entitledResolutions.first?.widthInPixels == 1920)
    }

    @Test func testGamesClientFetchMainGames() async throws {
        let client = GamesClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if url.absoluteString.contains("/v2/serverInfo") {
                let json = "{\"requestStatus\": {\"serverId\": \"NP-AMS-08\"}}"
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if url.absoluteString.contains("graphql") {
                // If it is panels query
                if request.url?.query?.contains("panels/MainV2") == true {
                    let json = """
                    {
                        "data": {
                            "panels": [
                                {
                                    "name": "MAIN",
                                    "sections": [
                                        {
                                            "items": [
                                                {
                                                    "__typename": "GameItem",
                                                    "app": {
                                                        "id": 1001,
                                                        "title": "Cyberpunk 2077",
                                                        "variants": [
                                                            {
                                                                "id": "1001-steam",
                                                                "appStore": "STEAM",
                                                                "gfn": {
                                                                    "library": {
                                                                        "selected": true
                                                                    }
                                                                }
                                                            }
                                                        ]
                                                    }
                                                }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        }
                    }
                    """
                    return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
                } else {
                    // appMetaData query
                    let json = """
                    {
                        "data": {
                            "apps": {
                                "items": [
                                    {
                                        "id": 1001,
                                        "title": "Cyberpunk 2077 (Enriched)",
                                        "images": {
                                            "GAME_BOX_ART": "https://img.nvidiagrid.net/art.jpg",
                                            "TV_BANNER": "https://img.nvidiagrid.net/banner.jpg"
                                        }
                                    }
                                ]
                            }
                        }
                    }
                    """
                    return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
                }
            }
            return (makeHTTPResponse(url: url, statusCode: 404), Data())
        }

        let games = try await client.fetchMainGames(token: "token", streamingBaseUrl: "https://test.com")
        #expect(games.count == 1)
        #expect(games.first?.id == "1001")
        #expect(games.first?.title == "Cyberpunk 2077 (Enriched)")
        #expect(games.first?.variants.first?.appStore == "STEAM")
    }

    @Test func testZoneClientFetchZones() async throws {
        let client = ZoneClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            
            if url.absoluteString.contains("queue") {
                let json = """
                {
                    "data": {
                        "NP-AMS-08": {
                            "QueuePosition": 5,
                            "Region": "EU-AMS",
                            "eta": 60000.0
                        }
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if url.absoluteString.contains("GFN_SERVERID_TO_REGION_MAPPING") {
                let json = """
                {
                    "data": {
                        "NP-AMS-08": {
                            "nuked": false
                        }
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            }
            
            return (makeHTTPResponse(url: url, statusCode: 404), Data())
        }
        
        let zones = try await client.fetchZones()
        #expect(zones.count == 1)
        #expect(zones.first?.id == "NP-AMS-08")
    }

    // MARK: - CloudMatchClient Tests

    @Test func testCloudMatchClientCreateSessionSuccess() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString.contains("/v2/session"))
            #expect(request.value(forHTTPHeaderField: "Authorization") == "GFNJWT mock-token")
            #expect(request.value(forHTTPHeaderField: "nv-device-os") == "MACOS")
            
            let json = """
            {
                "session": {
                    "sessionId": "mock-session-id",
                    "status": 2,
                    "gpuType": "RTX 4080",
                    "connectionInfo": [
                        {
                            "usage": 14,
                            "ip": "1.2.3.4",
                            "port": 443,
                            "resourcePath": "/nvst/"
                        },
                        {
                            "usage": 2,
                            "ip": "5.6.7.8",
                            "port": 5000,
                            "resourcePath": null
                        }
                    ],
                    "iceServerConfiguration": {
                        "iceServers": [
                            {
                                "urls": ["stun:stun.l.google.com:19302"],
                                "username": "user",
                                "credential": "cred"
                            }
                        ]
                    }
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }

        let input = SessionCreateRequest(
            appId: "123",
            internalTitle: "Test Game",
            token: "mock-token",
            zone: "NP-AMS-08",
            streamingBaseUrl: "https://streaming.com",
            settings: StreamSettings(),
            accountLinked: true
        )
        let info = try await client.createSession(input)
        #expect(info.sessionId == "mock-session-id")
        #expect(info.status == 2)
        #expect(info.gpuType == "RTX 4080")
        #expect(info.serverIp == "1.2.3.4")
        #expect(info.signalingUrl == "wss://1.2.3.4:443/nvst/")
        #expect(info.mediaConnectionInfo?.ip == "5.6.7.8")
        #expect(info.mediaConnectionInfo?.port == 5000)
        #expect(info.iceServers.first?.urls.first == "stun:stun.l.google.com:19302")
    }

    @Test func testCloudMatchClientCreateSessionFailure() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            return (makeHTTPResponse(url: url, statusCode: 400), "Error payload".data(using: .utf8)!)
        }

        let input = SessionCreateRequest(
            appId: "123",
            internalTitle: "Test Game",
            token: "mock-token",
            zone: "NP-AMS-08",
            streamingBaseUrl: nil,
            settings: StreamSettings(),
            accountLinked: false
        )
        await #expect(throws: CloudMatchError.self) {
            try await client.createSession(input)
        }
    }

    @Test func testCloudMatchClientPollAndStopSession() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            
            if request.httpMethod == "DELETE" {
                #expect(url.absoluteString.contains("/v2/session/sess-123"))
                return (makeHTTPResponse(url: url), Data())
            } else {
                #expect(url.absoluteString.contains("/v2/session/sess-123"))
                let json = """
                {
                    "session": {
                        "sessionId": "sess-123",
                        "status": 3
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            }
        }

        let info = try await client.pollSession(
            sessionId: "sess-123",
            token: "mock-token",
            base: "https://base.com",
            serverIp: nil,
            clientId: "cid",
            deviceId: "did"
        )
        #expect(info.sessionId == "sess-123")
        #expect(info.status == 3)

        // Test stopSession
        try await client.stopSession(
            sessionId: "sess-123",
            token: "mock-token",
            base: "https://base.com",
            clientId: "cid",
            deviceId: "did"
        )
    }

    @Test func testCloudMatchClientGetActiveSessions() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString.contains("/v2/sessions"))
            let json = """
            {
                "requestStatus": {
                    "statusCode": 200,
                    "statusDescription": "OK"
                },
                "sessions": [
                    {
                        "sessionId": "sess-active",
                        "status": 2,
                        "sessionRequestData": { "appId": "999" },
                        "connectionInfo": [
                            {
                                "usage": 14,
                                "ip": "9.9.9.9",
                                "port": 443
                            }
                        ]
                    }
                ]
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }

        let active = try await client.getActiveSessions(token: "mock-token", base: "https://base.com")
        #expect(active.count == 1)
        #expect(active[0].sessionId == "sess-active")
        #expect(active[0].appId == "999")
        #expect(active[0].serverIp == "9.9.9.9")
        #expect(active[0].signalingUrl == "wss://9.9.9.9:443/nvst/")
    }

    @Test func testCloudMatchClientClaimSessionQueue() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let json = """
            {
                "session": {
                    "sessionId": "sess-queue",
                    "status": 1,
                    "queuePosition": 5
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }

        let info = try await client.claimSession(
            sessionId: "sess-queue",
            serverIp: "10.0.0.1",
            token: "mock-token",
            base: "https://base.com",
            appId: "some-app-id",
            settings: StreamSettings()
        )
        #expect(info.status == 1)
        #expect(info.queuePosition == 5)
        #expect(info.isInQueue == true)
    }

    @Test func testCloudMatchClientClaimSessionReady() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        var getCalled = false
        var putCalled = false
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if request.httpMethod == "GET" {
                getCalled = true
                let json = """
                {
                    "session": {
                        "sessionId": "sess-ready",
                        "status": 2
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if request.httpMethod == "PUT" {
                putCalled = true
                #expect(url.absoluteString.contains("/v2/session/sess-ready"))
                let json = """
                {
                    "session": {
                        "sessionId": "sess-ready",
                        "status": 3
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            }
            throw URLError(.badURL)
        }

        let info = try await client.claimSession(
            sessionId: "sess-ready",
            serverIp: "10.0.0.1",
            token: "mock-token",
            base: "https://base.com",
            appId: "some-app-id",
            settings: StreamSettings()
        )
        #expect(getCalled)
        #expect(putCalled)
        #expect(info.status == 3)
    }

    @Test func testCloudMatchClientClaimSessionFailure8A8C() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            if request.httpMethod == "GET" {
                let json = """
                {
                    "session": {
                        "sessionId": "sess-failed-8a8c",
                        "status": 2
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if request.httpMethod == "PUT" {
                let json = """
                {
                    "session": {
                        "sessionId": "sess-failed-8a8c",
                        "status": 0
                    },
                    "requestStatus": {
                        "statusCode": 0,
                        "statusDescription": "UNKNOWN 8A8C0000",
                        "unifiedErrorCode": 0
                    }
                }
                """
                return (makeHTTPResponse(url: url, statusCode: 400), json.data(using: .utf8)!)
            }
            throw URLError(.badURL)
        }

        do {
            _ = try await client.claimSession(
                sessionId: "sess-failed-8a8c",
                serverIp: "10.0.0.1",
                token: "mock-token",
                base: "https://base.com",
                appId: "some-app-id",
                settings: StreamSettings()
            )
            Issue.record("Expected claimSession to fail, but it succeeded")
        } catch {
            let desc = error.localizedDescription
            #expect(desc.contains("UNKNOWN 8A8C0000"))
        }
    }

    @Test func testCloudMatchClientReportAdEvent() async {
        let client = CloudMatchClient(urlSession: mockSession)
        var putCalled = false
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(request.httpMethod == "PUT")
            putCalled = true
            return (makeHTTPResponse(url: url), Data())
        }

        await client.reportAdEvent(
            sessionId: "sess-ads",
            token: "mock-token",
            base: "https://base.com",
            serverIp: nil,
            clientId: "cid",
            deviceId: "did",
            adId: "ad-1",
            action: .start,
            watchedTimeMs: 1000,
            pausedTimeMs: 0
        )
        #expect(putCalled)
    }

    @Test func testAnyCodableStringDecodingFormats() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        
        let ipFormats: [String: String] = [
            "\"1.2.3.4\"": "1.2.3.4",
            "[\"10.0.0.1\", \"192.168.0.1\"]": "10.0.0.1",
            "1345682432": "80.53.124.0",
            "{\"value\": \"192.168.1.1\"}": "192.168.1.1",
            "{\"value\": 1345682432}": "80.53.124.0"
        ]
        
        for (jsonIp, expectedIp) in ipFormats {
            MockURLProtocol.requestHandler = { request in
                guard let url = request.url else { throw URLError(.badURL) }
                let json = """
                {
                    "session": {
                        "sessionId": "mock-sess",
                        "status": 2,
                        "connectionInfo": [
                            {
                                "usage": 14,
                                "ip": \(jsonIp),
                                "port": 443,
                                "resourcePath": "/nvst/"
                            }
                        ]
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            }
            
            let input = SessionCreateRequest(
                appId: "123",
                internalTitle: "Test Game",
                token: "mock-token",
                zone: "NP-AMS-08",
                streamingBaseUrl: "https://streaming.com",
                settings: StreamSettings(),
                accountLinked: true
            )
            
            let info = try await client.createSession(input)
            #expect(info.serverIp == expectedIp)
        }
    }

    @Test func testCloudMatchClientMediaUsage14Fallback() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let json = """
            {
                "session": {
                    "sessionId": "mock-sess",
                    "status": 2,
                    "connectionInfo": [
                        {
                            "usage": 14,
                            "port": 322,
                            "resourcePath": "rtsps://80-84-170-153.cloudmatchbeta.nvidiagrid.net:322"
                        },
                        {
                            "usage": 14,
                            "port": 48322,
                            "resourcePath": "rtsps://80-84-170-153.cloudmatchbeta.nvidiagrid.net:48322"
                        }
                    ]
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let input = SessionCreateRequest(
            appId: "123",
            internalTitle: "Test Game",
            token: "mock-token",
            zone: "NP-AMS-08",
            streamingBaseUrl: "https://streaming.com",
            settings: StreamSettings(),
            accountLinked: true
        )
        
        let info = try await client.createSession(input)
        #expect(info.serverIp == "")
        #expect(info.mediaConnectionInfo?.ip == "80.84.170.153")
        #expect(info.mediaConnectionInfo?.port == 48322)
    }

    @Test func testCloudMatchClientAdStateExtraction() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let json = """
            {
                "session": {
                    "sessionId": "mock-sess",
                    "status": 1,
                    "sessionAdsRequired": true,
                    "opportunity": {
                        "queuePaused": true,
                        "gracePeriodSeconds": 45,
                        "message": "Watch this ad to play"
                    },
                    "sessionAds": [
                        {
                            "adId": "ad-xyz",
                            "adUrl": "https://ad.com",
                            "mediaUrl": "https://video.com/ad.mp4",
                            "adLengthInSeconds": 15.5
                        }
                    ]
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let input = SessionCreateRequest(
            appId: "123",
            internalTitle: "Test Game",
            token: "mock-token",
            zone: "NP-AMS-08",
            streamingBaseUrl: "https://streaming.com",
            settings: StreamSettings(),
            accountLinked: true
        )
        
        let info = try await client.createSession(input)
        let adState = info.adState
        #expect(adState != nil)
        #expect(adState?.isAdsRequired == true)
        #expect(adState?.isQueuePaused == true)
        #expect(adState?.gracePeriodSeconds == 45)
        #expect(adState?.message == "Watch this ad to play")
        #expect(adState?.ads.count == 1)
        #expect(adState?.ads[0].adId == "ad-xyz")
        #expect(adState?.ads[0].adUrl == "https://ad.com")
        #expect(adState?.ads[0].mediaUrl == "https://video.com/ad.mp4")
        #expect(adState?.ads[0].adLengthInSeconds == 15.5)
    }

    @Test func testCloudMatchClientValidateSessionSuccess() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        let serverTimeStr = "Tue, 02 Jun 2026 19:40:00 GMT"
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let json = """
            {
                "session": {
                    "sessionId": "validate-xyz",
                    "status": 2
                }
            }
            """
            let headers = ["Date": serverTimeStr]
            return (makeHTTPResponse(url: url, headers: headers), json.data(using: .utf8)!)
        }

        let (info, serverDate) = try await client.validateSession(
            sessionId: "validate-xyz",
            token: "mock-token",
            base: "https://base.com",
            serverIp: nil
        )
        
        #expect(info.sessionId == "validate-xyz")
        #expect(info.status == 2)
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        let expectedDate = formatter.date(from: serverTimeStr)!
        #expect(abs(serverDate.timeIntervalSince(expectedDate)) < 1.0)
        #expect(UserDefaults.standard.double(forKey: "gfn.serverTimeOffset") != 0.0)
    }

    @Test func testCloudMatchClientValidateSessionFailure() async throws {
        let client = CloudMatchClient(urlSession: mockSession)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            return (makeHTTPResponse(url: url, statusCode: 404), Data())
        }

        do {
            _ = try await client.validateSession(
                sessionId: "validate-failed",
                token: "mock-token",
                base: "https://base.com",
                serverIp: nil
            )
            Issue.record("Expected validation to fail with sessionNotFound, but it succeeded")
        } catch CloudMatchError.sessionNotFound {
            // Success
        } catch {
            Issue.record("Expected sessionNotFound error, got: \(error)")
        }
    }

    @Test func testResumableSessionCodable() throws {
        let game = GameInfo(
            id: "game1",
            title: "Game Title",
            boxArtUrl: "http://box.jpg",
            heroBannerUrl: "http://hero.jpg",
            isInLibrary: true,
            variants: [
                GameVariant(id: "var1", appStore: "STEAM", appId: "123")
            ]
        )
        
        let session = SessionInfo(
            sessionId: "sess123",
            status: 2,
            zone: "NP-AMS-08",
            streamingBaseUrl: "https://streaming.com",
            serverIp: "1.1.1.1",
            signalingServer: "1.1.1.1:443",
            signalingUrl: "wss://1.1.1.1:443/nvst/",
            gpuType: "RTX 4080",
            queuePosition: nil,
            seatSetupStep: nil,
            iceServers: [],
            mediaConnectionInfo: MediaConnectionInfo(ip: "1.1.1.1", port: 48322),
            clientId: "client-id-abc",
            deviceId: "device-id-xyz",
            adState: nil
        )
        
        let resumable = ResumableSession(
            game: game,
            session: session,
            leftAtServerTime: Date(),
            gracePeriod: 120
        )
        
        let encoded = try JSONEncoder().encode(resumable)
        let decoded = try JSONDecoder().decode(ResumableSession.self, from: encoded)
        
        #expect(decoded.game.id == resumable.game.id)
        #expect(decoded.session.sessionId == resumable.session.sessionId)
        #expect(decoded.gracePeriod == resumable.gracePeriod)
        #expect(abs(decoded.leftAtServerTime.timeIntervalSince(resumable.leftAtServerTime)) < 0.1)
    }
}

