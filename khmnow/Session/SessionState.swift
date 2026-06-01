import Foundation

// MARK: - Stream Settings

nonisolated struct StreamSettings: Codable, Equatable {
    var resolution: String = "1920x1080"
    var fps: Int = 60
    var maxBitrateKbps: Int = 20_000 { didSet { maxBitrateKbps = min(maxBitrateKbps, 500_000) } }
    var codec: VideoCodec = .h264
    var colorQuality: ColorQuality = .sdr8bit
    var keyboardLayout: String = "en-US"
    var gameLanguage: String = "en_US"
    var enableL4S: Bool = false
    var micEnabled: Bool = false
    /// Radial deadzone applied to analog stick axes (0.0–1.0). Default 15%.
    var controllerDeadzone: Double = 0.15
    /// Which controller button triggers the GFN overlay on long-press. Default: Start (≡).
    var overlayTriggerButton: OverlayTriggerButton = .start
    /// Default Siri Remote input mode when a stream session starts.
    var defaultRemoteInputMode: RemoteInputMode = .mouse
    /// Preferred zone URL, e.g. "https://np-aws-us-n-virginia-1.cloudmatchbeta.nvidiagrid.net/"
    /// Defaults to the Thailand (Southeast Asia) server.
    var preferredZoneUrl: String? = "https://npa-bpc-bkk-01.cloudmatchbeta.nvidiagrid.net/"
    
    var autoBitrate: Bool = true
    
    var connectionMode: ConnectionOptimizationMode = .lowLatency
    var customFecRepairPercent: Int = 5
    var customPacketSize: Int = 1140
    var customUseOwd: Bool = true
    var customJitterThresholdUs: Int = 3000
    
    var effectiveMaxBitrateKbps: Int {
        if autoBitrate {
            let resolutionParts = resolution.split(separator: "x")
            let width = Int(resolutionParts.first ?? "1920") ?? 1920
            if width >= 3840 {
                return 300_000
            } else if width >= 1920 {
                return 50_000
            } else {
                return 30_000
            }
        } else {
            return maxBitrateKbps
        }
    }
    
    init() {}
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution) ?? "1920x1080"
        fps = try container.decodeIfPresent(Int.self, forKey: .fps) ?? 60
        maxBitrateKbps = try container.decodeIfPresent(Int.self, forKey: .maxBitrateKbps) ?? 20_000
        codec = try container.decodeIfPresent(VideoCodec.self, forKey: .codec) ?? .h264
        colorQuality = try container.decodeIfPresent(ColorQuality.self, forKey: .colorQuality) ?? .sdr8bit
        keyboardLayout = try container.decodeIfPresent(String.self, forKey: .keyboardLayout) ?? "en-US"
        gameLanguage = try container.decodeIfPresent(String.self, forKey: .gameLanguage) ?? "en_US"
        enableL4S = try container.decodeIfPresent(Bool.self, forKey: .enableL4S) ?? false
        micEnabled = try container.decodeIfPresent(Bool.self, forKey: .micEnabled) ?? false
        controllerDeadzone = try container.decodeIfPresent(Double.self, forKey: .controllerDeadzone) ?? 0.15
        overlayTriggerButton = try container.decodeIfPresent(OverlayTriggerButton.self, forKey: .overlayTriggerButton) ?? .start
        defaultRemoteInputMode = try container.decodeIfPresent(RemoteInputMode.self, forKey: .defaultRemoteInputMode) ?? .mouse
        preferredZoneUrl = try container.decodeIfPresent(String.self, forKey: .preferredZoneUrl) ?? "https://npa-bpc-bkk-01.cloudmatchbeta.nvidiagrid.net/"
        autoBitrate = try container.decodeIfPresent(Bool.self, forKey: .autoBitrate) ?? true
        connectionMode = try container.decodeIfPresent(ConnectionOptimizationMode.self, forKey: .connectionMode) ?? .lowLatency
        customFecRepairPercent = try container.decodeIfPresent(Int.self, forKey: .customFecRepairPercent) ?? 5
        customPacketSize = try container.decodeIfPresent(Int.self, forKey: .customPacketSize) ?? 1140
        customUseOwd = try container.decodeIfPresent(Bool.self, forKey: .customUseOwd) ?? true
        customJitterThresholdUs = try container.decodeIfPresent(Int.self, forKey: .customJitterThresholdUs) ?? 3000
    }
}

nonisolated enum ConnectionOptimizationMode: String, Codable, CaseIterable {
    case balanced = "Balanced"
    case lossResilient = "Loss Resilient"
    case lowLatency = "Low Latency"
    case custom = "Custom"
}

nonisolated enum OverlayTriggerButton: String, Codable, CaseIterable {
    case start   = "Start (≡)"
    case options = "Options/Back (⊟)"
}

nonisolated enum VideoCodec: String, Codable, CaseIterable {
    case h264 = "H264"
    case h265 = "H265"
    case av1  = "AV1"
}

nonisolated enum ColorQuality: String, Codable, CaseIterable {
    case sdr8bit  = "SDR8bit"
    case sdr10bit = "SDR10bit"
    case hdr10bit = "HDR10bit"

    var bitDepth: Int { self == .sdr8bit ? 8 : 10 }
    var chromaFormat: Int { self == .hdr10bit ? 2 : 1 }
}

// MARK: - ICE Server

nonisolated struct IceServer: Codable {
    let urls: [String]
    let username: String?
    let credential: String?
}

// MARK: - Queue Ads

nonisolated struct SessionAdMediaFile: Codable, Equatable {
    let mediaFileUrl: String?
    let encodingProfile: String?
}

nonisolated struct SessionAdInfo: Codable, Equatable, Identifiable {
    let adId: String
    let adUrl: String?
    let mediaUrl: String?
    let adMediaFiles: [SessionAdMediaFile]
    let adLengthInSeconds: Double?
    var id: String { adId }

    /// Returns the best available media URL.
    var preferredMediaURL: URL? {
        if let url = adMediaFiles.compactMap({ $0.mediaFileUrl.flatMap(URL.init) }).first { return url }
        if let url = adUrl.flatMap(URL.init) { return url }
        return mediaUrl.flatMap(URL.init)
    }
}

nonisolated struct SessionAdState: Codable, Equatable {
    let isAdsRequired: Bool
    let isQueuePaused: Bool?
    let gracePeriodSeconds: Int?
    let message: String?
    let ads: [SessionAdInfo]
}

// MARK: - Session Info (returned by CloudMatch)

nonisolated struct SessionInfo {
    let sessionId: String
    let status: Int
    let zone: String
    let streamingBaseUrl: String
    let serverIp: String
    let signalingServer: String
    let signalingUrl: String
    let gpuType: String?
    let queuePosition: Int?
    let seatSetupStep: Int?
    let iceServers: [IceServer]
    let mediaConnectionInfo: MediaConnectionInfo?
    let clientId: String
    let deviceId: String
    let adState: SessionAdState?

    /// True while the session is sitting in the GFN queue (no timeout applies).
    var isInQueue: Bool {
        if status == 1 { return true }
        if seatSetupStep == 1 { return true }
        return (queuePosition ?? 0) >= 1
    }
}

nonisolated struct MediaConnectionInfo {
    let ip: String
    let port: Int
}

// MARK: - Active Session Info

nonisolated struct ActiveSessionInfo {
    let sessionId: String
    let status: Int
    let appId: String?
    let serverIp: String?
    let signalingUrl: String?
}

// MARK: - Subscription / Entitlements

nonisolated struct EntitledResolution: Equatable {
    let widthInPixels: Int
    let heightInPixels: Int
    let framesPerSecond: Int

    var resolutionLabel: String { "\(widthInPixels)x\(heightInPixels)" }
}

nonisolated struct SubscriptionInfo {
    let membershipTier: String
    let isUnlimited: Bool
    let remainingMinutes: Int?
    let totalMinutes: Int?
    let entitledResolutions: [EntitledResolution]
}

// MARK: - Games

nonisolated struct GameInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let boxArtUrl: String?
    let heroBannerUrl: String?
    var isInLibrary: Bool
    var variants: [GameVariant]
}

nonisolated struct GameVariant: Equatable {
    let id: String
    let appStore: String
    var appId: String?

    var storeName: String {
        switch appStore {
        case "STEAM": return "Steam"
        case "EPIC_GAMES_STORE": return "Epic Games"
        case "GOG": return "GOG"
        case "EA_APP": return "EA App"
        case "UBISOFT": return "Ubisoft Connect"
        case "MICROSOFT": return "Xbox"
        case "BATTLENET": return "Battle.net"
        default: return appStore.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - Session Create Request

nonisolated struct SessionCreateRequest {
    let appId: String
    let internalTitle: String?
    let token: String
    let zone: String
    let streamingBaseUrl: String?
    let settings: StreamSettings
    let accountLinked: Bool
}
