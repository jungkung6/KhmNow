import SwiftUI

struct SettingsView: View {
    @Environment(AuthManager.self) var authManager
    @Environment(GamesViewModel.self) var viewModel

    @State private var showZonePicker = false
    @State private var isRunningBenchmark = false
    @State private var benchmarkProgress: Double = 0.0
    @State private var showBenchmarkResult = false
    @State private var currentBenchmarkResult: BenchmarkResult? = nil

    var body: some View {
        @Bindable var vm = viewModel

        NavigationStack {
            Form {
                Section("Stream Quality") {
                    Picker("Resolution", selection: $vm.streamSettings.resolution) {
                        let common = commonResolutions.filter { viewModel.availableResolutions.contains($0.res) }
                        let other  = viewModel.availableResolutions.filter { res in !commonResolutions.map(\.res).contains(res) }
                        if !common.isEmpty {
                            Section("TV Standards") {
                                ForEach(common, id: \.res) { item in
                                    Label("\(item.res)  —  \(item.badge)", systemImage: item.symbol)
                                        .tag(item.res)
                                }
                            }
                        }
                        if !other.isEmpty {
                            Section("Other") {
                                ForEach(other, id: \.self) { res in
                                    Text(res).tag(res)
                                }
                            }
                        }
                    }

                    Picker("Frame Rate", selection: $vm.streamSettings.fps) {
                        ForEach(viewModel.availableFps, id: \.self) { fps in
                            Text("\(fps) fps").tag(fps)
                        }
                    }

                    Picker("Codec", selection: $vm.streamSettings.codec) {
                        ForEach(VideoCodec.allCases, id: \.self) { codec in
                            Text(codec.rawValue).tag(codec)
                        }
                    }

                    Picker(selection: $vm.streamSettings.colorQuality) {
                        ForEach(ColorQuality.allCases, id: \.self) { q in
                            Text(colorQualityLabel(q)).tag(q)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Color Quality")
                            if vm.streamSettings.colorQuality == .hdr10bit {
                                Text("⚠️ Experimental — GFN may downscale to ~540p when HDR is enabled.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            } else if vm.streamSettings.colorQuality == .sdr10bit {
                                Text("Recommended — full resolution with better color than 8-bit.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Standard dynamic range, widely compatible.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Picker("Keyboard Layout", selection: $vm.streamSettings.keyboardLayout) {
                        Text("English (US)").tag("en-US")
                        Text("English (UK)").tag("en-GB")
                        Text("French").tag("fr-FR")
                        Text("German").tag("de-DE")
                        Text("Spanish").tag("es-ES")
                        Text("Italian").tag("it-IT")
                        Text("Portuguese (Brazil)").tag("pt-BR")
                        Text("Hindi (India)").tag("hi-IN")
                        Text("Japanese").tag("ja-JP")
                        Text("Korean").tag("ko-KR")
                    }

                    Picker("Game Language", selection: $vm.streamSettings.gameLanguage) {
                        Text("English (US)").tag("en_US")
                        Text("English (UK)").tag("en_GB")
                        Text("French").tag("fr_FR")
                        Text("German").tag("de_DE")
                        Text("Spanish").tag("es_ES")
                        Text("Italian").tag("it_IT")
                        Text("Portuguese").tag("pt_BR")
                        Text("Hindi").tag("hi_IN")
                        Text("Japanese").tag("ja_JP")
                        Text("Korean").tag("ko_KR")
                    }

                    Toggle(isOn: $vm.streamSettings.autoBitrate) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Auto Bitrate")
                            Text("Dynamically optimize streaming quality and bandwidth usage.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }

                    if !vm.streamSettings.autoBitrate {
                        LabeledContent("Max Bitrate") {
                            HStack(spacing: 16) {
                                Button {
                                    vm.streamSettings.maxBitrateKbps = max(15_000, vm.streamSettings.maxBitrateKbps - 5_000)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                Text("\(vm.streamSettings.maxBitrateKbps / 1000) Mbps")
                                    .monospacedDigit()
                                    .frame(minWidth: 72)
                                    .padding(.horizontal, 24)
                                Button {
                                    vm.streamSettings.maxBitrateKbps = min(500_000, vm.streamSettings.maxBitrateKbps + 5_000)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        LabeledContent("Max Bitrate") {
                            Text("Auto (Up to \(vm.streamSettings.effectiveMaxBitrateKbps / 1000) Mbps)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $vm.streamSettings.enableL4S) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Low Latency Mode (L4S)")
                            Text("Reduces buffering on networks with L4S support (requires a compatible router and ISP).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("Connection & Stabilization") {
                    Picker("Optimization Profile", selection: $vm.streamSettings.connectionMode) {
                        ForEach(ConnectionOptimizationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    if vm.streamSettings.connectionMode == .custom {
                        LabeledContent("FEC Repair Rate") {
                            HStack(spacing: 16) {
                                Button {
                                    vm.streamSettings.customFecRepairPercent = max(5, vm.streamSettings.customFecRepairPercent - 5)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(vm.streamSettings.customFecRepairPercent)%")
                                    .monospacedDigit()
                                    .frame(minWidth: 44)
                                    .padding(.horizontal, 24)
                                
                                Button {
                                    vm.streamSettings.customFecRepairPercent = min(30, vm.streamSettings.customFecRepairPercent + 5)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Picker("Packet Size (MTU)", selection: $vm.streamSettings.customPacketSize) {
                            Text("1000 — Low Latency Wi-Fi").tag(1000)
                            Text("1050 — Loss Resilient").tag(1050)
                            Text("1140 — Default").tag(1140)
                            Text("1280 — Standard").tag(1280)
                            Text("1400 — High MTU Wired").tag(1400)
                        }
                        
                        Toggle("Delay Congestion Control (OWD)", isOn: $vm.streamSettings.customUseOwd)
                        
                        LabeledContent("Jitter Threshold") {
                            HStack(spacing: 16) {
                                Button {
                                    vm.streamSettings.customJitterThresholdUs = max(1000, vm.streamSettings.customJitterThresholdUs - 500)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(Double(vm.streamSettings.customJitterThresholdUs) / 1000.0, specifier: "%.1f") ms")
                                    .monospacedDigit()
                                    .frame(minWidth: 64)
                                    .padding(.horizontal, 16)
                                
                                Button {
                                    vm.streamSettings.customJitterThresholdUs = min(10000, vm.streamSettings.customJitterThresholdUs + 500)
                                } label: {
                                    Image(systemName: "plus.circle")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            switch vm.streamSettings.connectionMode {
                            case .balanced:
                                Text("Standard GFN network parameters. Best for high-speed wired connections.")
                            case .lossResilient:
                                Text("Triples error correction data and lowers packet size. Best for packet loss, weak Wi-Fi, or powerline adapters.")
                            case .lowLatency:
                                Text("Lowers packet size to 1000 and tightens jitter limits to reduce bufferbloat. Best for standard home Wi-Fi networks.")
                            default:
                                EmptyView()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }
                }

                Section("Performance & Optimization") {
                    Button {
                        runNetworkBenchmark()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-Configure Best Performance")
                                if isRunningBenchmark {
                                    Text("Measuring latency, jitter, and packet loss (\(Int(benchmarkProgress * 100))%)…")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else {
                                    Text("Analyze your network connection to auto-tune stream parameters.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                            Spacer()
                            if isRunningBenchmark {
                                ProgressView()
                            } else {
                                Image(systemName: "gauge.with.needle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isRunningBenchmark)
                }

                Section("Server Region") {
                    Button {
                        showZonePicker = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Preferred Zone")
                                Text("Auto routing picks the best balance of ping and queue depth. Tap to pin a specific region.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            Spacer()
                            Text(zoneLabel(vm.streamSettings.preferredZoneUrl))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)

                    if vm.streamSettings.preferredZoneUrl != nil {
                        Button("Clear — use automatic routing") {
                            vm.streamSettings.preferredZoneUrl = nil
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Microphone") {
                    Toggle(isOn: $vm.streamSettings.micEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use Microphone")
                            Text("Enables voice chat via a connected Bluetooth headset or AirPods. Requires microphone permission.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section("Controller") {
                    LabeledContent {
                        HStack(spacing: 16) {
                            Button {
                                vm.streamSettings.controllerDeadzone = max(0.05, vm.streamSettings.controllerDeadzone - 0.01)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                            Text("\(Int(vm.streamSettings.controllerDeadzone * 100))%")
                                .monospacedDigit()
                                .frame(minWidth: 44)
                                .padding(.horizontal, 24)
                            Button {
                                vm.streamSettings.controllerDeadzone = min(0.30, vm.streamSettings.controllerDeadzone + 0.01)
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deadzone")
                            Text("Increase if your controller drifts at rest. Default: 15%.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    Picker(selection: $vm.streamSettings.overlayTriggerButton) {
                        ForEach(OverlayTriggerButton.allCases, id: \.self) { btn in
                            Text(btn.rawValue).tag(btn)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Overlay Button")
                            Text("Long-press this button during play to open the GFN overlay. Switch if it conflicts with an in-game action.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    Picker(selection: $vm.streamSettings.defaultRemoteInputMode) {
                        Text("Mouse").tag(RemoteInputMode.mouse)
                        Text("Gamepad").tag(RemoteInputMode.gamepad)
                        Text("DualSense").tag(RemoteInputMode.dualsense)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Default Input Mode")
                            Text("Siri Remote mode at stream start. Can be changed mid-session from the overlay menu.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    LabeledContent("Protocol", value: "XInput v2/v3")
                }

                Section("Account") {
                    if let user = authManager.session?.user {
                        LabeledContent("Name", value: user.displayName)
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                        if let sub = viewModel.subscription {
                            LabeledContent("Membership", value: sub.membershipTier)
                            if !sub.isUnlimited, let remaining = sub.remainingMinutes {
                                let hours = remaining / 60
                                let mins  = remaining % 60
                                LabeledContent("Time Remaining", value: hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m")
                            }
                        } else {
                            LabeledContent("Membership", value: user.membershipTier)
                        }
                    }

                    Button(role: .destructive) {
                        authManager.logout()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("")
            .sheet(isPresented: $showZonePicker) {
                ZonePickerView(selectedZoneUrl: $vm.streamSettings.preferredZoneUrl)
            }
            .alert("Optimization Recommendations", isPresented: $showBenchmarkResult, presenting: currentBenchmarkResult) { result in
                Button("Yes, Optimize Settings") {
                    applyBenchmarkChanges(result)
                }
                Button("No, Keep Current", role: .cancel) {}
            } message: { result in
                let currentMode = vm.streamSettings.connectionMode
                let currentRes = vm.streamSettings.resolution
                let currentFps = vm.streamSettings.fps
                let currentAuto = vm.streamSettings.autoBitrate
                
                Text("""
                    Benchmark Metrics:
                    • Ping: \(Int(result.pingMs)) ms
                    • Jitter: \(Int(result.jitterMs)) ms
                    • Packet Loss: \(Int(result.packetLossPercent))%
                    
                    Proposed Changes:
                    • Profile: \(currentMode.rawValue) → \(result.recommendedConnectionMode.rawValue)
                    • Resolution: \(currentRes) → \(result.recommendedResolution)
                    • Frame Rate: \(currentFps) fps → \(result.recommendedFps) fps
                    • Auto Bitrate: \(currentAuto ? "On" : "Off") → \(result.recommendedAutoBitrate ? "On" : "Off")
                    
                    Do you want to apply these performance optimizations?
                    """)
            }
        }
    }

    private func runNetworkBenchmark() {
        isRunningBenchmark = true
        benchmarkProgress = 0.0
        
        Task {
            var targetUrl = viewModel.streamSettings.preferredZoneUrl
            if targetUrl == nil {
                if let zones = try? await ZoneClient.shared.fetchZones(),
                   let best = zones.autoZone(isUnlimited: viewModel.subscription?.isUnlimited ?? false) {
                    targetUrl = best.zoneUrl
                }
            }
            
            let benchmarkUrl = targetUrl ?? "https://npa-bpc-bkk-01.cloudmatchbeta.nvidiagrid.net/"
            _ = await probeLatency(to: benchmarkUrl)
            
            var latencies: [Double] = []
            let totalProbes = 12
            var failedCount = 0
            
            for i in 0..<totalProbes {
                try? await Task.sleep(for: .milliseconds(50))
                if let ms = await probeLatency(to: benchmarkUrl) {
                    latencies.append(ms)
                } else {
                    failedCount += 1
                }
                benchmarkProgress = Double(i + 1) / Double(totalProbes)
            }
            
            let ping: Double
            if latencies.isEmpty {
                ping = 999.0
            } else {
                ping = latencies.reduce(0, +) / Double(latencies.count)
            }
            
            var jitter = 0.0
            if latencies.count > 1 {
                var diffSum = 0.0
                for i in 1..<latencies.count {
                    diffSum += abs(latencies[i] - latencies[i-1])
                }
                jitter = diffSum / Double(latencies.count - 1)
            }
            
            let packetLoss = (Double(failedCount) / Double(totalProbes)) * 100.0
            
            let recResolution: String
            if ping > 90.0 || packetLoss > 5.0 {
                recResolution = "1280x720"
            } else {
                recResolution = "1920x1080"
            }
            
            let recFps: Int
            if ping > 110.0 || packetLoss > 8.0 {
                recFps = 30
            } else {
                recFps = 60
            }
            
            let recMode: ConnectionOptimizationMode
            if packetLoss > 2.0 {
                recMode = .lossResilient
            } else if jitter > 6.0 {
                recMode = .lowLatency
            } else {
                recMode = .balanced
            }
            
            let result = BenchmarkResult(
                pingMs: ping,
                jitterMs: jitter,
                packetLossPercent: packetLoss,
                recommendedResolution: recResolution,
                recommendedFps: recFps,
                recommendedConnectionMode: recMode,
                recommendedAutoBitrate: true
            )
            
            await MainActor.run {
                self.currentBenchmarkResult = result
                self.isRunningBenchmark = false
                self.showBenchmarkResult = true
            }
        }
    }
    
    private func probeLatency(to urlString: String) async -> Double? {
        guard let url = URL(string: urlString) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 1.2
        let start = Date()
        do {
            _ = try await URLSession.gfnShared.data(for: req)
            return Date().timeIntervalSince(start) * 1000
        } catch {
            return nil
        }
    }
    
    private func applyBenchmarkChanges(_ result: BenchmarkResult) {
        viewModel.streamSettings.connectionMode = result.recommendedConnectionMode
        viewModel.streamSettings.resolution = result.recommendedResolution
        viewModel.streamSettings.fps = result.recommendedFps
        viewModel.streamSettings.autoBitrate = result.recommendedAutoBitrate
        viewModel.saveSettings()
    }

    private func zoneLabel(_ url: String?) -> String {
        guard let url else { return "Automatic" }
        // Extract zone ID from URL like "https://np-aws-us-n-virginia-1.cloudmatchbeta.nvidiagrid.net/"
        let host = URL(string: url)?.host ?? url
        return host.components(separatedBy: ".").first?.uppercased() ?? url
    }

    private struct ResolutionEntry { let res: String; let badge: String; let symbol: String }
    private let commonResolutions: [ResolutionEntry] = [
        ResolutionEntry(res: "1280x720",  badge: "HD",      symbol: "tv"),
        ResolutionEntry(res: "1920x1080", badge: "Full HD", symbol: "tv"),
        ResolutionEntry(res: "2560x1440", badge: "2K",      symbol: "tv"),
        ResolutionEntry(res: "3840x2160", badge: "4K",      symbol: "4k.tv"),
    ]

    private func colorQualityLabel(_ q: ColorQuality) -> String {
        switch q {
        case .sdr8bit: return "SDR 8-bit"
        case .sdr10bit: return "SDR 10-bit"
        case .hdr10bit: return "HDR 10-bit"
        }
    }
}

// MARK: - Zone Picker

private struct ZonePickerView: View {
    @Binding var selectedZoneUrl: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(GamesViewModel.self) private var viewModel

    @State private var zones: [GFNZone] = []
    @State private var isLoading = true
    @State private var error: String?

    private var groupedZones: [(region: String, label: String, flag: String, zones: [GFNZone])] {
        let grouped = Dictionary(grouping: zones) { $0.region }
        let order = ["US", "CA", "EU", "JP", "KR", "THAI", "MY"]
        let sortedRegions = order.filter { grouped[$0] != nil }
            + grouped.keys.filter { !order.contains($0) }.sorted()
        return sortedRegions.map { region in
            let meta = GFNZone.regionMeta[region] ?? (label: region, flag: "🌐")
            return (region, meta.label, meta.flag, grouped[region, default: []])
        }
    }

    private var autoZone: GFNZone? { zones.autoZone(isUnlimited: viewModel.subscription?.isUnlimited ?? false) }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading servers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView("Can't Load Servers", systemImage: "wifi.exclamationmark",
                                          description: Text(error))
                } else {
                    List {
                        // Auto option
                        Section {
                            Button {
                                selectedZoneUrl = nil
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Automatic")
                                            .font(.body.weight(.semibold))
                                        if let best = autoZone {
                                            Text("Best: \(best.id) · Q\(best.queuePosition)\(best.pingMs.map { " · \($0) ms" } ?? "")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedZoneUrl == nil {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }

                        // Zones by region
                        ForEach(groupedZones, id: \.region) { group in
                            Section("\(group.flag) \(group.label)") {
                                ForEach(group.zones) { zone in
                                    Button {
                                        selectedZoneUrl = zone.zoneUrl
                                        dismiss()
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(zone.id)
                                                    .font(.body)
                                                HStack(spacing: 8) {
                                                    Label("Q \(zone.queuePosition)", systemImage: "person.3.fill")
                                                        .foregroundStyle(queueColor(zone.queuePosition))
                                                    if let ping = zone.pingMs {
                                                        Label("\(ping) ms", systemImage: "wifi")
                                                            .foregroundStyle(pingColor(ping))
                                                    } else if zone.isMeasuring {
                                                        Label("…", systemImage: "wifi")
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                                .font(.caption)
                                            }
                                            Spacer()
                                            if selectedZoneUrl == zone.zoneUrl {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                            } else if autoZone?.id == zone.id {
                                                Text("Best")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.green)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.15), in: Capsule())
                                            }
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Server Region")
            .task {
                await loadZones()
            }
        }
    }

    private func loadZones() async {
        isLoading = true
        error = nil
        do {
            zones = try await ZoneClient.shared.fetchZones()
            isLoading = false
            // Measure pings concurrently in batches of 6
            let batchSize = 6
            for start in stride(from: 0, to: zones.count, by: batchSize) {
                let end = min(start + batchSize, zones.count)
                let batch = zones[start..<end]
                await withTaskGroup(of: (String, Int?).self) { group in
                    for zone in batch {
                        group.addTask {
                            let ping = await ZoneClient.shared.measurePing(to: zone.zoneUrl)
                            return (zone.id, ping)
                        }
                    }
                    for await (id, ping) in group {
                        if let idx = zones.firstIndex(where: { $0.id == id }) {
                            zones[idx].pingMs = ping
                            zones[idx].isMeasuring = false
                        }
                    }
                }
            }
        } catch {
            isLoading = false
            self.error = error.localizedDescription
        }
    }

    private func queueColor(_ q: Int) -> Color {
        if q <= 5 { return .green }
        if q <= 15 { return .yellow }
        if q <= 30 { return .orange }
        return .red
    }

    private func pingColor(_ ms: Int) -> Color {
        if ms < 30  { return .green }
        if ms < 80  { return .yellow }
        if ms < 150 { return .orange }
        return .red
    }
}

struct BenchmarkResult: Identifiable {
    var id: String { "\(pingMs)-\(jitterMs)-\(packetLossPercent)" }
    let pingMs: Double
    let jitterMs: Double
    let packetLossPercent: Double
    
    let recommendedResolution: String
    let recommendedFps: Int
    let recommendedConnectionMode: ConnectionOptimizationMode
    let recommendedAutoBitrate: Bool
}
