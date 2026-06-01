# KhmNow - GeForce NOW tvOS Client (Thailand)

KhmNow is a tvOS client for GeForce NOW Thailand, featuring code and design patterns forked from the excellent [CloudNow](https://github.com/owenselles/CloudNow) project by [owenselles](https://github.com/owenselles). This community-driven wrapper brings GeForce NOW streaming directly to your Apple TV with native tvOS controls, liquid glass visual interfaces, and custom controller mappings.

> [!IMPORTANT]
> **Independent Community Project:** This project is entirely independent and is **NOT** sponsored, affiliated, or endorsed by NVIDIA, Pentavalent (the GeForce NOW operator in Thailand), or any other commercial entity. It is provided for personal, non-commercial use only.

---

## Features

- **Cozy & Minimal Aesthetics:** A gorgeous, minimal green design optimized for tvOS 26 that blends beautifully with the system UI.
- **Low Latency Defaults:** Out-of-the-box streaming settings pre-configured for `.lowLatency` (Wi-Fi/Ethernet optimized) connection modes to guarantee the smoothest gameplay.
- **Dynamic Auto Bitrate:** Automatically scales connection bitrates (up to 75 Mbps for 4K, 50 Mbps for 1080p, and 30 Mbps for 720p) to prevent router bufferbloat and packet drops.
- **Network Performance Benchmark:** An built-in testing utility in Settings to probe ping, jitter, and packet loss against GeForce NOW Thailand servers, offering side-by-side proposed parameter auto-tuning.
- **Premium Queue Progress Card:** Glassmorphic queue tracking widget that displays live positions and security slot allocations while handling queue advertisements smoothly.
- **AVAudioSession Resolution:** Fully resolved Bluetooth HFP/A2DP session management to keep audio output crisp and prevent game sound muting regressions.
- **Session Recovery & Teardown:** Automatically detects active remote GFN sessions on launch, giving options to seamlessly rejoin or terminate them.
- **Controller Support:** Full MFi, Xbox, and PlayStation controller mapping with deadzone adjustments (5% - 30%) and customizable Siri Remote settings.

---

## Requirements

* **Software & Tools:**
  - Mac running macOS Sequoia 15+ (or compatible version)
  - **Xcode 26.5+**
  - Apple Developer Account (free personal tier is sufficient)
* **Hardware & OS:**
  - Apple TV 4K (2nd generation or later recommended) or Apple TV HD.
  - **tvOS 26.5+** (Note: This project is **tested and verified only on tvOS 26.5**).
* **GeForce NOW Account:** An active account with GeForce NOW Thailand (operated by Pentavalent).
* **Game Controller:** An MFi-certified gamepad, Xbox Series X/S, or PlayStation DualSense controller.

---

### Installation & Setup Guide (Build from Source)

Since tvOS apps compiled with free developer accounts expire every 7 days, you must build the project from source using Xcode to deploy it to your Apple TV.

### Step 1: Clone the Repository
```bash
git clone https://github.com/jungkung6/KhmNow.git
cd KhmNow
```

### Step 2: Add the WebRTC Package Dependency
1. Open `khmnow.xcodeproj` in Xcode 26.5+.
2. Go to **File** → **Add Package Dependencies...**.
3. Paste the WebRTC library URL: `https://github.com/livekit/webrtc-xcframework`
4. Select the target **WebRTC** and click Add Package.

### Step 3: Configure Signing & Team
1. In Xcode, select the **khmnow** project at the top of the left navigator pane.
2. Select the **khmnow** target under Targets.
3. Go to the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. Under **Team**, select your Apple Developer Team account (personal/free accounts work perfectly).
6. If Xcode displays a bundle identifier conflict error, modify the **Bundle Identifier** field to a unique value (e.g., `com.yourname.khmnow`).

### Step 4: Run & Deploy
1. Pair your Apple TV with Xcode over your network: **Xcode → Window → Devices and Simulators** → Pair Apple TV.
2. Select your paired **Apple TV** as the run destination from the destination selector at the top of Xcode.
3. Press **Cmd + R** (or click the Play button) to build, sign, and install the app.
4. Xcode will launch the app on your Apple TV automatically!

---

## Project Structure & Architecture

```
KhmNow/
├── khmnow/
│   ├── Auth/
│   │   ├── AuthManager.swift           # @Observable auth manager with Keychain token caching
│   │   └── NVIDIAAuthAPI.swift         # OAuth 2.0 PKCE device authorization flow client
│   ├── Session/
│   │   ├── SessionState.swift          # Session states, stream presets, and GFN models
│   │   ├── CloudMatchClient.swift      # Client for GFN CloudMatch APIs (create, poll, terminate)
│   │   ├── GamesClient.swift           # GFN catalog client via GraphQL persisted queries
│   │   ├── GFNURLSession.swift         # Custom SSL/TLS trust delegates for *.nvidiagrid.net
│   │   └── ZoneClient.swift            # Gateway region mapping and queue depth monitor
│   ├── Streaming/
│   │   ├── GFNStreamController.swift   # WebRTC PeerConnection, SDP munging, and stream control
│   │   ├── SDPMunger.swift             # Codec-aware WebRTC SDP offer/answer filter
│   │   ├── SignalingClient.swift       # WebSocket client for GFN signaling / ICE exchange
│   │   └── InputSender.swift           # GameController mappings to custom GFN XInput binary protocol
│   ├── Video/
│   │   └── VideoSurfaceView.swift      # AVSampleBufferDisplayLayer video surface wrapper
│   ├── UI/
│   │   ├── HomeView.swift              # Main dashboard with Continue Playing & Favorites rows
│   │   ├── LibraryView.swift           # User's game catalog with search, sorting, and favorites
│   │   ├── StoreView.swift             # Complete GFN catalog browser with search and details
│   │   ├── SettingsView.swift          # Stream quality selectors and Network Performance Benchmark
│   │   ├── MainTabView.swift           # Root tvOS sidebar/tab navigation shell
│   │   ├── LoginView.swift             # OAuth login screen with QR code and PIN display
│   │   ├── QueueAdPlayerView.swift     # AVPlayer wrapper for mandatory queue advertisements
│   │   └── StreamView.swift            # Full-screen video player HUD stats and Queue Card
│   └── Assets.xcassets                 # Premium tvOS 26 layered parallax App Icon stacks
├── khmnow.xcodeproj                    # Xcode project configuration
├── khmnowTests/                        # Core unit test suites for Auth, Clients, and Inputs
└── khmnowUITests/                      # tvOS user interface interaction tests
```

---

## Known Limitations

- **No App Store Release:** GeForce NOW does not have a public client API. This is a community project and must be sideloaded.
- **7-day Re-sign limit:** Free accounts expire every 7 days; use Sideloadly or an alt server to auto-refresh the signature.


---

## Acknowledgements

- [owenselles/CloudNow](https://github.com/owenselles/CloudNow) — The original developer whose code forms the layout and architecture foundation for this project.
- [PrintedWaste](https://printedwaste.com) — Community GFN zone mapping API.
- [livekit/webrtc-xcframework](https://github.com/livekit/webrtc-xcframework) — High-quality WebRTC wrapper framework.
