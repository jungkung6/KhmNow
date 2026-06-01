# Release 0.10 Task Tracking - GeForce Now Apple TV (KhmNow)

This file tracks progress, detailed micro-tasks, and notes for the release 0.10 phase of KhmNow.

## Release 0.10 Checklist

### Phase 1: Project Initialization & Configuration
- [x] Create feature branch `feature/init-webview-bridge` from `develop`
- [x] Create custom skill `tvos-khmnow-dev` at `/Users/jung6/.gemini/skills/tvos-khmnow-dev/SKILL.md`
- [x] Create workspace instructions `INSTRUCTIONS.md` at `/Users/jung6/myproject/khmnow/INSTRUCTIONS.md`
- [x] Create release tracking file `release-0.10.md`

### Phase 2: Dynamic WebView Wrapper Implementation
- [x] Create `DynamicWebView.h` in `khmnow/` directory
- [x] Create `DynamicWebView.m` in `khmnow/` directory with dynamic `WKWebView` runtime instantiation
- [x] Inject iPadOS Safari custom user agent via KVC
- [x] Handle layout updates dynamically

### Phase 3: Swift Bridging Header Setup
- [x] Create bridging header `khmnow-Bridging-Header.h`
- [x] Configure Xcode project settings `SWIFT_OBJC_BRIDGING_HEADER` to use the bridging header

### Phase 4: SwiftUI WebView Bridge
- [x] Create `SwiftUIWebView.swift` implementing `UIViewRepresentable`
- [x] Update `ContentView.swift` to display `SwiftUIWebView` loaded with GeForce Now client URL

### Phase 5: Game Controller Bridge
- [x] Add `GameController` framework linking
- [x] Handle controller connection notifications
- [x] Map physical controller button presses to custom JS scripts injected into the WebView

### Phase 6: Verification & Build
- [x] Verify build compiles successfully via command-line `xcodebuild` targeting physical Apple TV device
- [x] Test launch status

### Phase 8: Connection, Audio & Performance Benchmarking Optimizations
- [x] Integrate optimized defaults (`.lowLatency` connection mode & capped auto-bitrate limit parameters)
- [x] Implement Network Performance Benchmark tool in settings to measure latency, jitter, and packet loss
- [x] Implement Side-by-side Proposed Settings diff with user confirmation alert dialog
- [x] Fix AVAudioSession category options logic (.playback with allowBluetoothA2DP, .playAndRecord with allowBluetoothHFP) to restore game audio
- [x] Deploy and launch on physical Bedroom Apple TV, confirming correct connection and sound

### Phase 9: Resumption Error & WebRTC ICE Optimization (Proposed & Implemented)
- [x] Pass active `appId` during session resumption `PUT` requests (`claimSession`) to fix server error `UNKNOWN 8A8C0000`
- [x] Add method, URL, header, body, and response logs for GFN session operations
- [x] Resolve WebRTC connection failures (`ICE failed`):
  - Resolve FQDNs for both signaling and session control hosts into IPv4 candidates
  - Inject candidates for both UDP media ports (`47998` and `48322`) against all resolved IPs
  - Use lowercase `udp` protocol tag in candidate strings
  - Loop and register candidates across all four SDP m-lines (`sdpMLineIndex` `0..3`)
- [x] Scale 4K auto-bitrate limit up to 300 Mbps in `SessionState.swift`

---

## Session Continuation Notes
* **Current Active Branch:** `develop`
* **Next Immediate Steps:**
  1. Verify the on-device stream resumption connection after the ICE and bitrate optimizations.
  2. Continue benchmarking network stream stability at 300 Mbps on the Apple TV.




