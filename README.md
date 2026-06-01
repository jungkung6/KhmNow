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

* **Hardware:** Apple TV 4K (2nd generation or later recommended) or Apple TV HD.
* **GeForce NOW Account:** An active account with GeForce NOW Thailand (operated by Pentavalent).
* **Game Controller:** An MFi-certified gamepad, Xbox Series X/S, or PlayStation DualSense controller.

---

## Installation & Setup Guide

Whether you are a casual user looking to install the app or a developer compiling from source, follow the respective guide below.

### Method 1: For Non-Developers (Sideloading using Sideloadly)

Sideloadly is a free tool that lets you install apps (`.ipa` files) on Apple TV using a standard Mac or Windows PC.

#### Step 1: Prep your Apple TV
1. On your Apple TV, go to **Settings** → **System** → **Software Updates** and ensure you are on the latest tvOS version.
2. Go to **Settings** → **General** → **Privacy & Security**. Scroll down and make sure **Developer Mode** is visible and **Enabled**. (If not visible, you must pair Xcode first or use Apple Configurator to enable it).
3. Ensure your Apple TV and your computer are on the same local Wi-Fi or Ethernet network.

#### Step 2: Download Sideloadly
1. Download and install **Sideloadly** on your Mac or Windows PC from [sideloadly.io](https://sideloadly.io).

#### Step 3: Compile/Obtain the `.ipa`
1. You can build the `.ipa` from the source using Xcode (see power user instructions below) or download the pre-compiled version from the Releases page.

#### Step 4: Sideload the App
1. Open Sideloadly.
2. Connect your Apple TV to your computer. On macOS, go to Xcode → Window → Devices and Simulators to make sure your Apple TV is paired. Once paired, Sideloadly will auto-detect it under **Device**.
3. Under **Apple Account**, enter your Apple ID email address (your personal free developer account).
4. Drag and drop the `KhmNow.ipa` file into Sideloadly.
5. Click **Start**. Sideloadly will ask for your Apple ID password (this is sent securely to Apple to sign the app) and two-factor code.
6. Once it says **Done**, the **KhmNow** app icon will appear on your Apple TV home screen!

> [!NOTE]
> Free Apple Developer accounts require apps to be re-signed every **7 days**. Sideloadly can automatically refresh the signature over Wi-Fi if your computer is on and connected to the same network.

---

### Method 2: For Power Users / Developers (Build from Source)

If you want to build the code yourself using Xcode:

#### Step 1: Clone the Repository
```bash
git clone https://github.com/jungkung6/KhmNow.git
cd KhmNow
```

#### Step 2: Add the WebRTC Package Dependency
1. Open `khmnow.xcodeproj` in Xcode 16+.
2. Go to **File** → **Add Package Dependencies...**.
3. Paste the URL: `https://github.com/livekit/webrtc-xcframework`
4. Select the target **WebRTC** and click Add Package.

#### Step 3: Configure Signing & Team
1. In Xcode, click on the **khmnow** project at the top of the left navigator pane.
2. Select the **khmnow** target under Targets.
3. Go to the **Signing & Capabilities** tab.
4. Check **Automatically manage signing**.
5. Under **Team**, select your Apple Developer Team account (personal accounts work perfectly).
6. If Xcode displays a bundle identifier conflict error, modify the **Bundle Identifier** field to a unique value (e.g., `com.yourname.khmnow`).

#### Step 4: Run & Deploy
1. Pair your Apple TV with Xcode over your network: **Xcode → Window → Devices and Simulators** → Pair Apple TV.
2. Select your paired **Apple TV** as the run destination from the destination selector at the top of Xcode.
3. Press **Cmd + R** (or click the Play button) to build, sign, and install the app.
4. Xcode will launch the app on your Apple TV automatically!

---

## Directory Architecture

```
KhmNow/
├── khmnow/
│   ├── Auth/           # OAuth 2.0 PKCE, token caching, and keychain storage
│   ├── Session/        # GraphQL catalog fetching and GFN CloudMatch endpoints
│   ├── Streaming/      # WebRTC PeerConnection, SDP munging, and XInput binary protocols
│   ├── Video/          # AVSampleBufferDisplayLayer surface handlers
│   ├── UI/             # HomeView dashboard, premium QueueProgress cards, and SettingsView
│   └── Assets.xcassets # Parallax 3-layer app icons and brand assets
├── khmnow.xcodeproj    # Xcode project structure
├── khmnowTests/        # Test cases (Core clients, input mappings, SDP parsing)
└── khmnowUITests/      # Integration and layout interface tests
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
