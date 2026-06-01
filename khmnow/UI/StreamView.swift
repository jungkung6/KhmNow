import Charts
import SwiftUI

private enum LoadingPhase: Equatable {
    case finding
    case inQueue(Int?)
    case preparing
    case timedOut
}

struct StreamView: View {
    let game: GameInfo
    var settings: StreamSettings = StreamSettings()
    var existingSession: ActiveSessionInfo? = nil
    /// When set, skips CloudMatch entirely and reconnects WebRTC directly using the stored session.
    var directSession: SessionInfo? = nil
    let onDismiss: () -> Void
    /// Called when the user leaves without ending the session so the caller can offer a resume.
    var onLeave: ((GameInfo, SessionInfo) -> Void)? = nil

    @Environment(AuthManager.self) var authManager
    @Environment(GamesViewModel.self) var viewModel
    @State private var streamController = GFNStreamController()
    @State private var showOverlay = false
    @State private var showExitConfirmation = false
    @State private var loadingPhase: LoadingPhase = .finding
    @State private var createdSession: SessionInfo?
    @State private var sessionToken: String?
    @State private var isLeavingResumable = false
    @State private var showKeyboardInput = false
    // Per-ad state tracking to avoid duplicate reports
    @State private var adReportedAction: [String: AdAction] = [:]
    @State private var connectionAttempts = 0

    private let cloudMatchClient = CloudMatchClient()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch streamController.state {
            case .idle, .connecting:
                connectingView
            case .streaming:
                streamingView
            case .disconnected(let reason):
                disconnectedView(reason)
            case .failed(let message):
                failedView(message)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .task { await startSession() }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if !isLeavingResumable {
                if let session = createdSession, let token = sessionToken {
                    Task { [cloudMatchClient] in
                        try? await cloudMatchClient.stopSession(
                            sessionId: session.sessionId,
                            token: token,
                            base: session.streamingBaseUrl,
                            clientId: session.clientId,
                            deviceId: session.deviceId
                        )
                    }
                }
            }
            streamController.disconnect()
        }
        .sheet(isPresented: $showKeyboardInput) {
            StreamKeyboardSheet(
                onSend: { text in
                    Task {
                        await streamController.sendText(text)
                    }
                },
                onBackspace: {
                    streamController.sendBackspace()
                },
                onEnter: {
                    streamController.sendEnter()
                },
                onDismiss: {
                    showKeyboardInput = false
                }
            )
        }
        // During streaming, VideoSurfaceView is first responder and intercepts Menu via UIKit,
        // signaling us through menuPressCount. .onExitCommand only fires in non-streaming states
        // (loading, error) when the focus engine is active.
        .onChange(of: streamController.menuPressCount) { _, _ in
            toggleOverlay()
        }
        .onExitCommand {
            if streamController.state != .streaming {
                disconnect()
            }
        }
    }

    // MARK: Connecting

    private var connectingView: some View {
        VStack(spacing: 40) {
            if case .inQueue(let pos) = loadingPhase {
                // Premium Queue Progress UI
                VStack(spacing: 24) {
                    // Header Badge
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.headline)
                        Text("GEFORCE NOW™ QUEUE")
                            .font(.subheadline.weight(.heavy))
                            .tracking(1.5)
                    }
                    .foregroundStyle(Color(red: 0.46, green: 0.73, blue: 0.0)) // Nvidia Green
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.46, green: 0.73, blue: 0.0).opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0.46, green: 0.73, blue: 0.0).opacity(0.3), lineWidth: 1)
                    )

                    VStack(spacing: 8) {
                        Text("Starting \(game.title)…")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Please wait while we set up your session.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    // Queue Position Card
                    VStack(spacing: 16) {
                        if let pos, pos > 0 {
                            VStack(spacing: 4) {
                                Text("\(pos)")
                                    .font(.system(size: 96, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color(red: 0.46, green: 0.73, blue: 0.0), .white],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .shadow(color: Color(red: 0.46, green: 0.73, blue: 0.0).opacity(0.3), radius: 15, x: 0, y: 5)
                                
                                Text("PLAYERS AHEAD OF YOU")
                                    .font(.caption.weight(.bold))
                                    .tracking(2)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .tint(Color(red: 0.46, green: 0.73, blue: 0.0))
                                    .scaleEffect(1.5)
                                Text("SECURED A SPOT, ESTIMATING POSITION...")
                                    .font(.caption.weight(.bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(height: 140)
                        }
                    }
                    .frame(width: 440, height: 180)
                    .background(.black.opacity(0.4))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(red: 0.46, green: 0.73, blue: 0.0).opacity(0.6), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

                    // Show ad player when GFN requires watching an ad to stay in queue
                    if let adState = createdSession?.adState,
                       adState.isAdsRequired,
                       let ad = adState.ads.first {
                        QueueAdPlayerView(
                            ad: ad,
                            onStart:  { id in reportAd(id: id, action: .start)  },
                            onPause:  { id in reportAd(id: id, action: .pause)  },
                            onResume: { id in reportAd(id: id, action: .resume) },
                            onFinish: { id, ms in reportAd(id: id, action: .finish, watchedMs: ms) },
                            message:  adState.message
                        )
                        .frame(maxWidth: 560)
                    }

                    Button("Cancel Session") { disconnect() }
                        .buttonStyle(.bordered)
                        .tint(.red)
                }
                .padding(40)
                .background(.ultraThinMaterial)
                .cornerRadius(32)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                .compositingGroup()
            } else {
                VStack(spacing: 24) {
                    if case .timedOut = loadingPhase {
                        Image(systemName: "clock.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                    } else {
                        ProgressView()
                            .scaleEffect(2)
                            .tint(.white)
                    }
                    Text("Starting \(game.title)…")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(loadingLabel)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut, value: loadingPhase)

                    // Show ad player when GFN requires watching an ad to stay in queue
                    if let adState = createdSession?.adState,
                       adState.isAdsRequired,
                       let ad = adState.ads.first {
                        QueueAdPlayerView(
                            ad: ad,
                            onStart:  { id in reportAd(id: id, action: .start)  },
                            onPause:  { id in reportAd(id: id, action: .pause)  },
                            onResume: { id in reportAd(id: id, action: .resume) },
                            onFinish: { id, ms in reportAd(id: id, action: .finish, watchedMs: ms) },
                            message:  adState.message
                        )
                        .frame(maxWidth: 560)
                    }

                    HStack(spacing: 24) {
                        if case .timedOut = loadingPhase {
                            Button("Retry") {
                                connectionAttempts = 0
                                Task { await startSession() }
                            }
                            .buttonStyle(.bordered)
                            .tint(.blue)
                        }
                        Button("Cancel") { disconnect() }
                            .buttonStyle(.bordered)
                            .tint(loadingPhase == .timedOut ? .red : .secondary)
                    }
                }
                .compositingGroup()
            }
        }
    }

    private var loadingLabel: String {
        switch loadingPhase {
        case .finding:
            return "Connecting to a GeForce NOW server…"
        case .inQueue(let pos):
            if let pos { return "In queue · Position \(pos)" }
            return "In queue…"
        case .preparing:
            return "Preparing your game… This can take a minute"
        case .timedOut:
            return "Server took too long to respond."
        }
    }

    // MARK: Streaming

    private var streamingView: some View {
        ZStack {
            VideoSurfaceViewRepresentable(streamController: streamController, showOverlay: showOverlay)
                .ignoresSafeArea()

            if showOverlay {
                pauseMenu
                    .transition(.opacity)
            }

            if let warning = streamController.timeWarning, !showOverlay {
                timeWarningBanner(warning)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: streamController.timeWarning)
        .animation(.easeInOut(duration: 0.2), value: showOverlay)
        .onChange(of: showOverlay) { _, showing in
            // Pause game input while overlay is open in gamepad mode so D-pad
            // navigates overlay buttons instead of moving the in-game character.
            streamController.setInputPaused(showing && streamController.remoteMode != .mouse)
        }
        .alert("End Session?", isPresented: $showExitConfirmation) {
            Button("End Session", role: .destructive) { disconnect() }
            Button("Keep Playing", role: .cancel) { }
        } message: {
            Text("This will end your GeForce NOW session. To return later, use Leave Game instead.")
        }
    }

    // MARK: Pause Menu

    private var pauseMenu: some View {
        HStack(alignment: .top, spacing: 40) {
            // Actions
            VStack(spacing: 16) {
                Button {
                    toggleOverlay()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    streamController.toggleRemoteMode()
                } label: {
                    Label(remoteModeLabel, systemImage: remoteModeIcon)
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)

                Button {
                    showKeyboardInput = true
                } label: {
                    Label("Keyboard Input", systemImage: "keyboard")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)

                Button {
                    leave()
                } label: {
                    Label("Leave Game", systemImage: "house")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)

                Button(role: .destructive) {
                    showExitConfirmation = true
                } label: {
                    Label("End Session", systemImage: "xmark.circle")
                        .frame(minWidth: 180)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            // Live stats
            VStack(alignment: .leading, spacing: 10) {
                metricRow(
                    icon: "network",
                    label: "RTT",
                    value: "\(Int(streamController.stats.rttMs)) ms",
                    history: streamController.pingHistory,
                    color: pingColor(streamController.stats.rttMs)
                )
                metricRow(
                    icon: "speedometer",
                    label: "FPS",
                    value: "\(Int(streamController.stats.fps))",
                    history: streamController.fpsHistory,
                    color: fpsColor(streamController.stats.fps)
                )
                metricRow(
                    icon: "wifi",
                    label: "Bitrate",
                    value: "\(streamController.stats.bitrateKbps / 1000) Mbps",
                    history: streamController.bitrateHistory,
                    color: .cyan
                )
                Divider().overlay(.white.opacity(0.4))
                Label("\(streamController.stats.resolutionWidth)×\(streamController.stats.resolutionHeight) @ \(Int(streamController.stats.fps))fps", systemImage: "tv")
                Label("Loss \(String(format: "%.1f", streamController.stats.packetLossPercent))%", systemImage: "arrow.triangle.2.circlepath")
                if !streamController.stats.gpuType.isEmpty {
                    Label(streamController.stats.gpuType, systemImage: "cpu")
                }
                if let sub = viewModel.subscription, !sub.isUnlimited, let rem = sub.remainingMinutes {
                    Divider().overlay(.white.opacity(0.4))
                    Label {
                        Text(rem >= 60 ? "\(rem / 60)h \(rem % 60)m remaining" : "\(rem)m remaining")
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(rem < 30 ? .orange : .white.opacity(0.7))
                    }
                    .foregroundStyle(rem < 30 ? .orange : .white)
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.white)
        }
        .padding(32)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(60)
        .compositingGroup()
    }

    private var remoteModeLabel: String {
        switch streamController.remoteMode {
        case .mouse:     return "Remote: Mouse"
        case .gamepad:   return "Remote: Gamepad"
        case .dualsense: return "Remote: DualSense"
        }
    }

    private var remoteModeIcon: String {
        switch streamController.remoteMode {
        case .mouse:     return "cursorarrow"
        case .gamepad:   return "gamecontroller"
        case .dualsense: return "hand.point.up.left"
        }
    }

    private func metricRow(icon: String, label: String, value: String, history: [Double], color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text("\(label): \(value)")
                .foregroundStyle(color)
                .frame(width: 130, alignment: .leading)
            if history.count > 1 {
                Chart {
                    ForEach(Array(history.enumerated()), id: \.offset) { (idx, val) in
                        LineMark(x: .value("t", idx), y: .value("v", val))
                            .foregroundStyle(color)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 80, height: 24)
            }
        }
    }

    private func pingColor(_ ms: Double) -> Color {
        if ms < 30  { return .green }
        if ms < 80  { return .yellow }
        if ms < 150 { return .orange }
        return .red
    }

    private func fpsColor(_ fps: Double) -> Color {
        if fps >= 55 { return .green }
        if fps >= 30 { return .yellow }
        return .red
    }

    // MARK: Time Warning Banner

    private func timeWarningBanner(_ warning: StreamTimeWarning) -> some View {
        let (color, icon, message): (Color, String, String) = {
            let timeText = warning.secondsLeft.map { " (\($0)s left)" } ?? ""
            switch warning.code {
            case 3: return (.red,    "clock.badge.xmark",     "Session ending soon\(timeText)")
            case 2: return (.orange, "clock.badge.exclamationmark", "~5 minutes remaining\(timeText)")
            default: return (.yellow, "clock",                "Session limit approaching\(timeText)")
            }
        }()
        return Label(message, systemImage: icon)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(color.opacity(0.85), in: Capsule())
            .padding(.top, 40)
    }

    // MARK: Disconnected / Failed

    private func disconnectedView(_ reason: String) -> some View {
        statusView(
            icon: "wifi.slash",
            title: "Disconnected",
            message: reason,
            color: .yellow
        )
    }

    private func failedView(_ message: String) -> some View {
        statusView(
            icon: "exclamationmark.triangle",
            title: "Stream Failed",
            message: entitlementMessage(from: message),
            color: .red
        )
    }

    private func entitlementMessage(from raw: String) -> String {
        if raw.uppercased().contains("ENTITLEMENT") || raw.contains("3237093650") {
            return "\(game.title) is not in your GeForce NOW library."
        }
        if raw.contains("SESSION_LIMIT_EXCEEDED") {
            return "A previous session is still active. Please wait a moment and try again."
        }
        return raw
    }

    private func statusView(icon: String, title: String, message: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(color)
            Text(title)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 24) {
                Button("Retry") {
                    connectionAttempts = 0
                    Task { await startSession() }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                Button("Exit") { disconnect() }
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
        }
        .padding(60)
        .compositingGroup()
    }

    // MARK: Actions

    private func startSession() async {
        // Prevent automatic reconnection if we already tried and failed/disconnected.
        // The user must click the "Retry" button manually to reset this counter.
        if connectionAttempts > 0 {
            print("[StreamView] Suppressing automatic connection attempt (already tried \(connectionAttempts) time(s))")
            return
        }
        connectionAttempts += 1

        // Reset stream controller (handles retry from failed/disconnected state)
        streamController.disconnect()

        // Reconnect path — RESUME PUT tells the server to rebuild its media endpoint,
        // then connect WebRTC as soon as we get a single status 2/3 (no double-poll wait).
        if let direct = directSession {
            loadingPhase = .preparing
            do {
                let token = try await authManager.resolveToken()
                sessionToken = token
                let provider = authManager.session?.provider
                let streamingBaseUrl = provider?.streamingServiceUrl ?? NVIDIAAuth.defaultStreamingUrl
                let base = streamingBaseUrl.hasSuffix("/") ? String(streamingBaseUrl.dropLast()) : streamingBaseUrl

                var sessionInfo = try await cloudMatchClient.claimSession(
                    sessionId: direct.sessionId,
                    serverIp: direct.serverIp,
                    token: token,
                    base: base,
                    appId: game.variants.first?.appId ?? game.variants.first?.id,
                    settings: settings
                )
                createdSession = sessionInfo

                // Poll until ready, requiring 2 consecutive ready polls (status 2/3) to ensure server media is fully up.
                let timeout: TimeInterval = 60
                let start = Date()
                var readyStreak = 0
                while readyStreak < 2 {
                    if Date().timeIntervalSince(start) > timeout {
                        loadingPhase = .timedOut
                        return
                    }
                    if sessionInfo.status == 2 || sessionInfo.status == 3 {
                        readyStreak += 1
                    } else {
                        readyStreak = 0
                    }
                    if readyStreak >= 2 { break }

                    try await Task.sleep(for: .seconds(2))
                    sessionInfo = try await cloudMatchClient.pollSession(
                        sessionId: sessionInfo.sessionId,
                        token: token,
                        base: sessionInfo.streamingBaseUrl,
                        serverIp: sessionInfo.serverIp.isEmpty ? nil : sessionInfo.serverIp,
                        clientId: sessionInfo.clientId,
                        deviceId: sessionInfo.deviceId
                    )
                    createdSession = sessionInfo
                }

                viewModel.recordPlayed(game)
                await streamController.connect(session: sessionInfo, settings: settings)
            } catch {
                streamController.fail(with: error.localizedDescription)
            }
            return
        }

        // Stop any previously created server session before opening a new one.
        // Skip for resume — we want to keep the existing session alive.
        if let session = createdSession, let token = sessionToken, existingSession == nil {
            try? await cloudMatchClient.stopSession(
                sessionId: session.sessionId,
                token: token,
                base: session.streamingBaseUrl,
                clientId: session.clientId,
                deviceId: session.deviceId
            )
        }
        createdSession = nil
        loadingPhase = .finding
        do {
            let token = try await authManager.resolveToken()
            sessionToken = token
            let provider = authManager.session?.provider
            let streamingBaseUrl = provider?.streamingServiceUrl ?? NVIDIAAuth.defaultStreamingUrl
            let base = streamingBaseUrl.hasSuffix("/") ? String(streamingBaseUrl.dropLast()) : streamingBaseUrl

            var sessionInfo: SessionInfo

            if let existing = existingSession, let serverIp = existing.serverIp {
                // Resume path: attach to the existing session without creating a new one
                sessionInfo = try await cloudMatchClient.claimSession(
                    sessionId: existing.sessionId,
                    serverIp: serverIp,
                    token: token,
                    base: base,
                    appId: existing.appId ?? game.variants.first?.appId ?? game.variants.first?.id,
                    settings: settings
                )
            } else {
                // New session path
                guard let appId = game.variants.first?.appId ?? game.variants.first?.id else { return }

                // Prefer the user-selected zone URL; fall back to the provider's default.
                let sessionBase = settings.preferredZoneUrl ?? base

                let request = SessionCreateRequest(
                    appId: appId,
                    internalTitle: game.title,
                    token: token,
                    zone: "",
                    streamingBaseUrl: sessionBase,
                    settings: settings,
                    accountLinked: true
                )

                do {
                    sessionInfo = try await cloudMatchClient.createSession(request)
                } catch CloudMatchError.sessionCreateFailed(let msg) where msg.contains("SESSION_LIMIT_EXCEEDED") {
                    // Stale server session is blocking creation — stop all active sessions and retry once.
                    let staleSessions = (try? await cloudMatchClient.getActiveSessions(token: token, base: base)) ?? []
                    for stale in staleSessions {
                        let staleBase = stale.serverIp.map { "https://\($0)" } ?? base
                        try? await cloudMatchClient.stopSession(sessionId: stale.sessionId, token: token, base: staleBase)
                    }
                    sessionInfo = try await cloudMatchClient.createSession(request)
                }
            }
            createdSession = sessionInfo

            // Poll with readyPollStreak confirmation (requires 2 consecutive ready polls).
            // While in queue: no timeout — user waits indefinitely with position updates.
            // After queue clears: 180-second setup timeout applies.
            var readyPollStreak = 0
            var setupStartTime: Date? = nil

            while readyPollStreak < 2 {
                // Update loading phase and apply timeout only outside the queue
                if sessionInfo.isInQueue {
                    loadingPhase = .inQueue(sessionInfo.queuePosition)
                    setupStartTime = nil
                } else {
                    if setupStartTime == nil { setupStartTime = Date() }
                    if let t = setupStartTime, Date().timeIntervalSince(t) > 180 {
                        loadingPhase = .timedOut
                        return
                    }
                    loadingPhase = .preparing
                }

                if sessionInfo.status == 2 || sessionInfo.status == 3 {
                    readyPollStreak += 1
                } else {
                    readyPollStreak = 0
                }

                if readyPollStreak >= 2 { break }

                try await Task.sleep(for: .seconds(2))
                sessionInfo = try await cloudMatchClient.pollSession(
                    sessionId: sessionInfo.sessionId,
                    token: token,
                    base: sessionInfo.streamingBaseUrl,
                    serverIp: sessionInfo.serverIp.isEmpty ? nil : sessionInfo.serverIp,
                    clientId: sessionInfo.clientId,
                    deviceId: sessionInfo.deviceId
                )
                createdSession = sessionInfo
            }

            viewModel.recordPlayed(game)
            await streamController.connect(session: sessionInfo, settings: settings)
        } catch {
            streamController.fail(with: error.localizedDescription)
        }
    }

    // Leaves the stream locally without stopping the server session.
    // GFN keeps the session alive for ~1–2 minutes so it can be resumed from home.
    private func leave() {
        isLeavingResumable = true
        if let session = createdSession {
            onLeave?(game, session)
        }
        streamController.disconnect()
        onDismiss()
    }

    private func disconnect() {
        // Intentional end — clear any pending resumable session
        viewModel.resumableSession = nil
        // Tell the server to stop the session so it doesn't linger
        if let session = createdSession, let token = sessionToken {
            Task {
                try? await cloudMatchClient.stopSession(
                    sessionId: session.sessionId,
                    token: token,
                    base: session.streamingBaseUrl,
                    clientId: session.clientId,
                    deviceId: session.deviceId
                )
            }
        }
        createdSession = nil
        streamController.disconnect()
        onDismiss()
    }

    private func reportAd(id: String, action: AdAction, watchedMs: Int? = nil) {
        // Prevent duplicate reports for the same action on the same ad
        guard adReportedAction[id] != action else { return }
        adReportedAction[id] = action
        guard let session = createdSession, let token = sessionToken else { return }
        Task {
            await cloudMatchClient.reportAdEvent(
                sessionId: session.sessionId,
                token: token,
                base: session.streamingBaseUrl,
                serverIp: session.serverIp.isEmpty ? nil : session.serverIp,
                clientId: session.clientId,
                deviceId: session.deviceId,
                adId: id,
                action: action,
                watchedTimeMs: watchedMs
            )
        }
    }

    private func toggleOverlay() {
        showOverlay.toggle()
        // Pause input forwarding while the overlay is visible so swipes don't move
        // the game cursor and keyboard shortcuts don't reach the game accidentally.
        streamController.setInputPaused(showOverlay)
    }
}
