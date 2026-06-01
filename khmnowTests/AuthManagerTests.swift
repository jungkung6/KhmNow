import Testing
import Foundation
@testable import KhmNow

@Suite("AuthManager and API Tests", .serialized)
@MainActor
struct AuthManagerTests {
    init() {
        KeychainService.isTesting = true
        KeychainService.delete()
    }
    
    @Test func testInitializeWithoutSession() async {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        let auth = AuthManager(api: api)
        
        await auth.initialize()
        #expect(!auth.isAuthenticated)
        #expect(auth.session == nil)
    }

    @Test func testInitializeWithStoredSession() async throws {
        let tokens = AuthTokens(
            accessToken: "a",
            refreshToken: "r",
            idToken: "i",
            expiresAt: Date().addingTimeInterval(3600),
            clientToken: "ct",
            clientTokenExpiresAt: Date().addingTimeInterval(3600)
        )
        let user = AuthUser(userId: "u", displayName: "D", email: "e", avatarUrl: nil, membershipTier: "Free")
        let provider = LoginProvider(idpId: "idp", code: "code", displayName: "Name", streamingServiceUrl: "https://stream.com", priority: 1)
        let session = AuthSession(provider: provider, tokens: tokens, user: user)
        let data = try JSONEncoder().encode(session)
        try KeychainService.save(data)
        
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        let auth = AuthManager(api: api)
        
        await auth.initialize()
        #expect(auth.isAuthenticated)
        #expect(auth.session?.user.userId == "u")
    }

    @Test func testLogout() async throws {
        let tokens = AuthTokens(
            accessToken: "a",
            refreshToken: "r",
            idToken: "i",
            expiresAt: Date().addingTimeInterval(3600),
            clientToken: "ct",
            clientTokenExpiresAt: Date().addingTimeInterval(3600)
        )
        let user = AuthUser(userId: "u", displayName: "D", email: "e", avatarUrl: nil, membershipTier: "Free")
        let provider = LoginProvider(idpId: "idp", code: "code", displayName: "Name", streamingServiceUrl: "https://stream.com", priority: 1)
        let session = AuthSession(provider: provider, tokens: tokens, user: user)
        let data = try JSONEncoder().encode(session)
        try KeychainService.save(data)
        
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        let auth = AuthManager(api: api)
        
        await auth.initialize()
        #expect(auth.isAuthenticated)
        
        auth.logout()
        #expect(!auth.isAuthenticated)
        #expect((try? KeychainService.load()) == nil)
    }

    @Test func testLoginFlow() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        let auth = AuthManager(api: api)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            
            if url.absoluteString.contains("serviceUrls") {
                let json = """
                {
                    "gfnServiceInfo": {
                        "gfnServiceEndpoints": [
                            {
                                "idpId": "BPC",
                                "loginProviderCode": "BPC",
                                "loginProviderDisplayName": "BPC",
                                "streamingServiceUrl": "https://streaming.com",
                                "loginProviderPriority": 1
                            }
                        ]
                    }
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if url.absoluteString.contains("device/authorize") {
                let json = """
                {
                    "user_code": "USER-CODE",
                    "device_code": "dev-code",
                    "verification_uri": "https://nvidia.com/pair",
                    "verification_uri_complete": "https://nvidia.com/pair?c=USER-CODE",
                    "expires_in": 600,
                    "interval": 1
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if url.absoluteString.contains("token") {
                let json = """
                {
                    "access_token": "acc_token",
                    "refresh_token": "ref_token",
                    "id_token": "id_token",
                    "expires_in": 3600
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if url.absoluteString.contains("userinfo") {
                let json = """
                {
                    "sub": "user123",
                    "preferred_username": "Test User",
                    "email": "test@test.com"
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            } else if url.absoluteString.contains("client_token") {
                let json = """
                {
                    "client_token": "client_token_val",
                    "expires_in": 3600
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            }
            
            return (makeHTTPResponse(url: url, statusCode: 404), Data())
        }
        
        auth.login()
        
        // Wait/poll until auth.isAuthenticated is true
        var retries = 0
        while !auth.isAuthenticated && retries < 200 {
            try? await Task.sleep(for: .milliseconds(50))
            retries += 1
        }
        
        #expect(auth.isAuthenticated)
        #expect(auth.session?.tokens.accessToken == "acc_token")
        #expect(auth.session?.user.userId == "user123")
    }

    @Test func testResolveToken() async throws {
        let tokens = AuthTokens(
            accessToken: "valid_token",
            refreshToken: "r",
            idToken: "i",
            expiresAt: Date().addingTimeInterval(3600),
            clientToken: "ct",
            clientTokenExpiresAt: Date().addingTimeInterval(3600)
        )
        let user = AuthUser(userId: "u", displayName: "D", email: "e", avatarUrl: nil, membershipTier: "Free")
        let provider = LoginProvider(idpId: "idp", code: "code", displayName: "Name", streamingServiceUrl: "https://stream.com", priority: 1)
        let session = AuthSession(provider: provider, tokens: tokens, user: user)
        let data = try JSONEncoder().encode(session)
        try KeychainService.save(data)
        
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        let auth = AuthManager(api: api)
        
        await auth.initialize()
        
        let token = try await auth.resolveToken()
        #expect(token == "i")
    }

    // MARK: - NVIDIAAuthAPI direct tests

    @Test func testPKCEGeneration() {
        let pkce = PKCE.generate()
        #expect(!pkce.verifier.isEmpty)
        #expect(!pkce.challenge.isEmpty)
        #expect(pkce.verifier.count >= 43)
    }

    @Test func testNVIDIAAuthAPIFetchProviders() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString == NVIDIAAuth.serviceUrlsEndpoint)
            let json = """
            {
                "gfnServiceInfo": {
                    "gfnServiceEndpoints": [
                        {
                            "idpId": "BPC",
                            "loginProviderCode": "BPC",
                            "loginProviderDisplayName": "BPC",
                            "streamingServiceUrl": "https://stream.com",
                            "loginProviderPriority": 2
                        }
                    ]
                }
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let providers = try await api.fetchProviders()
        #expect(providers.count == 1)
        #expect(providers[0].code == "BPC")
        #expect(providers[0].displayName == "bro.game")
    }

    @Test func testNVIDIAAuthAPIExchangeCode() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString == NVIDIAAuth.tokenEndpoint)
            #expect(request.httpMethod == "POST")
            
            let json = """
            {
                "access_token": "acc",
                "refresh_token": "ref",
                "id_token": "id",
                "expires_in": 3600
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let tokens = try await api.exchangeCode("code", verifier: "verifier", redirectURI: "app://callback")
        #expect(tokens.accessToken == "acc")
        #expect(tokens.refreshToken == "ref")
    }

    @Test func testNVIDIAAuthAPIRefreshTokensFallback() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        var callCount = 0
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            callCount += 1
            if callCount == 1 {
                return (makeHTTPResponse(url: url, statusCode: 401), "Unauthorized".data(using: .utf8)!)
            } else {
                let json = """
                {
                    "access_token": "acc2",
                    "refresh_token": "ref2",
                    "expires_in": 3600
                }
                """
                return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
            }
        }
        
        let tokens = try await api.refreshTokens("old-refresh")
        #expect(callCount == 2)
        #expect(tokens.accessToken == "acc2")
    }

    @Test func testNVIDIAAuthAPIFetchClientToken() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString == NVIDIAAuth.clientTokenEndpoint)
            let json = """
            {
                "client_token": "ct-val",
                "expires_in": 600
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let (token, _) = try await api.fetchClientToken(accessToken: "acc")
        #expect(token == "ct-val")
    }

    @Test func testNVIDIAAuthAPIRefreshWithClientToken() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            let json = """
            {
                "access_token": "acc3",
                "refresh_token": "ref3",
                "expires_in": 3600
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let tokens = try await api.refreshWithClientToken("client-t", userId: "user-1")
        #expect(tokens.accessToken == "acc3")
    }

    @Test func testNVIDIAAuthAPIPollDeviceTokenErrors() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        var callCount = 0
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            callCount += 1
            let errorType: String
            if callCount == 1 {
                errorType = "authorization_pending"
            } else if callCount == 2 {
                errorType = "slow_down"
            } else if callCount == 3 {
                errorType = "access_denied"
            } else {
                errorType = "expired_token"
            }
            
            let json = """
            {
                "error": "\(errorType)",
                "error_description": "Detail \(errorType)"
            }
            """
            return (makeHTTPResponse(url: url, statusCode: 400), json.data(using: .utf8)!)
        }
        
        await #expect(throws: AuthError.self) {
            _ = try await api.pollForDeviceToken(deviceCode: "code", interval: 1, expiresIn: 5)
        }
        #expect(callCount == 3)
    }

    @Test func testNVIDIAAuthAPIFetchUserInfoFallback() async throws {
        let mockSession = makeMockSession()
        let api = NVIDIAAuthAPI(session: mockSession)
        
        MockURLProtocol.requestHandler = { request in
            guard let url = request.url else { throw URLError(.badURL) }
            #expect(url.absoluteString == NVIDIAAuth.userinfoEndpoint)
            let json = """
            {
                "sub": "sub-123",
                "preferred_username": "pref-user",
                "email": "user@gmail.com"
            }
            """
            return (makeHTTPResponse(url: url), json.data(using: .utf8)!)
        }
        
        let tokens = AuthTokens(accessToken: "invalid_jwt", refreshToken: nil, idToken: nil, expiresAt: Date().addingTimeInterval(3600))
        let user = try await api.fetchUserInfo(tokens: tokens)
        #expect(user.userId == "sub-123")
        #expect(user.displayName == "pref-user")
    }
}

