import Testing
import Foundation
@testable import KhmNow

@Suite("Streaming and Input Tests", .serialized)
struct StreamingTests {

    @Test func testSDPMungerPreferCodec() {
        let originalSDP = """
        v=0
        o=- 12345 2 IN IP4 127.0.0.1
        s=-
        t=0 0
        m=video 9 UDP/TLS/RTP/SAVPF 96 97 98
        a=rtpmap:96 H264/90000
        a=rtpmap:97 H265/90000
        a=rtpmap:98 AV1/90000
        """

        let munged = SDPMunger.preferCodec(originalSDP, codec: .h265)
        #expect(munged.contains("a=rtpmap:97 H265/90000"))
        #expect(!munged.contains("a=rtpmap:96 H264/90000"))
        #expect(!munged.contains("a=rtpmap:98 AV1/90000"))
    }

    @Test func testSDPMungerBandwidthInjection() {
        let originalSDP = """
        v=0
        m=audio 9 RTP/SAVPF 111
        a=fmtp:111 minptime=10
        m=video 9 RTP/SAVPF 96
        """

        let munged = SDPMunger.injectBandwidth(originalSDP, videoKbps: 50000, audioKbps: 128)
        #expect(munged.contains("b=AS:50000"))
        #expect(munged.contains("b=AS:128"))
        #expect(munged.contains("stereo=1"))
    }

    @Test func testGamepadMapper() {
        let buttons = GamepadMapper.mapButtons(
            buttonA: 1.0, buttonB: 0.0, buttonX: 0.0, buttonY: 0.0,
            leftShoulder: 0.0, rightShoulder: 0.0, leftTrigger: 0.0, rightTrigger: 0.0,
            buttonSelect: 0.0, buttonStart: 0.0, buttonL3: 0.0, buttonR3: 0.0,
            dpadUp: 0.0, dpadDown: 0.0, dpadLeft: 0.0, dpadRight: 0.0
        )
        #expect(buttons.count == 16)
        #expect(buttons[0] == 1.0) // Button A
        #expect(buttons[1] == 0.0) // Button B

        let axes = GamepadMapper.mapAxes(leftX: 0.5, leftY: -0.5, rightX: 0.0, rightY: 0.0)
        #expect(axes.count == 4)
        #expect(axes[0] == 0.5)
        #expect(axes[1] == 0.5) // Negated
    }

    @Test func testInputEncoderHeartbeat() {
        let encoder = InputEncoder()
        let heartbeat = encoder.encodeHeartbeat()
        #expect(heartbeat.count == 4)
        #expect(heartbeat[0] == 2)
    }

    @Test func testInputEncoderKeyboard() {
        let encoder = InputEncoder()
        let packet = encoder.encodeKeyboard(down: true, vk: 0x41, scancode: 0x1E, modifiers: 0x0)
        #expect(packet.count == 18)
        #expect(packet[0] == 3) // keyDown type is 3 in packet[0] (Little-Endian)
    }

    @Test func testInputEncoderProtocolV3() {
        let encoder = InputEncoder()
        encoder.setProtocolVersion(3)

        // 1. Keyboard Event (v3 wrapped)
        let keyPacket = encoder.encodeKeyboard(down: true, vk: 0x41, scancode: 0x1E, modifiers: 0x0)
        #expect(keyPacket.count == 28) // 10 bytes header + 18 bytes packet
        #expect(keyPacket[0] == 0x23)
        #expect(keyPacket[9] == 0x22)
        #expect(keyPacket[10] == 3) // type inside keyboard packet

        // 2. Mouse Move Event (v3 wrapped)
        let movePacket = encoder.encodeMouseMove(dx: 10, dy: -20)
        #expect(movePacket.count == 34) // 12 bytes header + 22 bytes packet
        #expect(movePacket[0] == 0x23)
        #expect(movePacket[9] == 0x21)
        #expect(movePacket[11] == 22) // payload size in header

        // 3. Mouse Button Event (v3 wrapped)
        let btnPacket = encoder.encodeMouseButton(down: true, button: 1)
        #expect(btnPacket.count == 28) // 10 bytes header + 18 bytes packet
        #expect(btnPacket[0] == 0x23)
        #expect(btnPacket[9] == 0x22)

        // 4. Mouse Wheel Event (v3 wrapped)
        let wheelPacket = encoder.encodeMouseWheel(delta: 120)
        #expect(wheelPacket.count == 32) // 10 bytes header + 22 bytes packet
        #expect(wheelPacket[0] == 0x23)
        #expect(wheelPacket[9] == 0x22)

        // 5. Gamepad Event (v3 wrapped)
        let gamepadPacket = encoder.encodeGamepad(
            controllerId: 0,
            buttons: 0x1000,
            leftTrigger: 100,
            rightTrigger: 200,
            leftStickX: 1000,
            leftStickY: -1000,
            rightStickX: 0,
            rightStickY: 0,
            gamepadBitmap: 1
        )
        #expect(gamepadPacket.count == 54) // 16 bytes header + 38 bytes packet
        #expect(gamepadPacket[0] == 0x23)
        #expect(gamepadPacket[9] == 0x26)
        #expect(gamepadPacket[13] == 0x21)
        #expect(gamepadPacket[15] == 38)
    }

    @Test func testInputSenderEventForwarding() {
        let mockChannel = MockDataChannelSender()
        let sender = InputSender(channel: mockChannel)

        // Test that events are forwarded when not paused
        sender.isPaused = false
        sender.sendKeyEvent(down: true, vk: 0x41, scancode: 0x1E, modifiers: 0x0)
        sender.sendMouseMove(dx: 5, dy: 10)
        sender.sendMouseButton(down: true, button: 1)
        sender.sendMouseWheel(delta: -1)

        #expect(mockChannel.sentPackets.count == 4)
        #expect(mockChannel.sentPackets[0][0] == 3) // keydown
        #expect(mockChannel.sentPackets[1][0] == 7) // mouseRel
        #expect(mockChannel.sentPackets[2][0] == 8) // mouseBtnDown
        #expect(mockChannel.sentPackets[3][0] == 10) // mouseWheel

        // Test that events are NOT forwarded when paused
        mockChannel.sentPackets.removeAll()
        sender.isPaused = true
        sender.sendKeyEvent(down: true, vk: 0x41, scancode: 0x1E, modifiers: 0x0)
        sender.sendMouseMove(dx: 5, dy: 10)
        sender.sendMouseButton(down: true, button: 1)
        sender.sendMouseWheel(delta: -1)

        #expect(mockChannel.sentPackets.isEmpty)
    }

    @Test func testInputSenderLifecycleAndSettings() {
        let mockChannel = MockDataChannelSender()
        let sender = InputSender(channel: mockChannel)

        // Test remote input mode toggling
        sender.remoteMode = .mouse
        sender.toggleRemoteMode()
        #expect(sender.remoteMode == .gamepad)

        sender.toggleRemoteMode()
        #expect(sender.remoteMode == .dualsense)

        sender.toggleRemoteMode()
        #expect(sender.remoteMode == .mouse)

        // Test properties
        sender.deadzone = 0.20
        #expect(sender.deadzone == 0.20)
        sender.overlayTriggerButton = .options
        #expect(sender.overlayTriggerButton == .options)
        
        // Test protocol version updates on encoder via sender
        sender.setProtocolVersion(3)
        #expect(sender.encoder.encodeHeartbeat().count == 4) // Heartbeat remains 4 bytes in v3
    }

    @Test func testSDPMungerH265SafetyRewrites() {
        let sdpWithTier = """
        v=0
        m=video 9 UDP/TLS/RTP/SAVPF 98
        a=rtpmap:98 H265/90000
        a=fmtp:98 profile-id=1;level-id=200;tier-flag=1
        """

        let rewrittenTier = SDPMunger.rewriteH265TierFlag(sdpWithTier)
        #expect(rewrittenTier.contains("tier-flag=0"))
        #expect(!rewrittenTier.contains("tier-flag=1"))

        let rewrittenLevel = SDPMunger.rewriteH265LevelId(sdpWithTier)
        #expect(rewrittenLevel.contains("level-id=183")) // capped to 183 because profile-id=1

        let sdpWithProfile2 = """
        v=0
        m=video 9 UDP/TLS/RTP/SAVPF 99
        a=rtpmap:99 H265/90000
        a=fmtp:99 profile-id=2;level-id=170
        """
        let rewrittenLevel2 = SDPMunger.rewriteH265LevelId(sdpWithProfile2)
        #expect(rewrittenLevel2.contains("level-id=153")) // capped to 153 because profile-id=2
    }

    @Test func testSDPMungerPreferCodecFallbackAndSorting() {
        // Test fallback to H264 when AV1 is requested but not present
        let sdpOnlyH264 = """
        v=0
        m=video 9 UDP/TLS/RTP/SAVPF 96
        a=rtpmap:96 H264/90000
        """
        let mungedAV1 = SDPMunger.preferCodec(sdpOnlyH264, codec: .av1)
        #expect(mungedAV1.contains("H264"))

        // Test sorting H.265 Main profile PTs to the front
        let sdpH265Profiles = """
        v=0
        m=video 9 UDP/TLS/RTP/SAVPF 96 97
        a=rtpmap:96 H265/90000
        a=fmtp:96 profile-id=2;level-id=150
        a=rtpmap:97 H265/90000
        a=fmtp:97 profile-id=1;level-id=150
        """
        let mungedSorting = SDPMunger.preferCodec(sdpH265Profiles, codec: .h265)
        #expect(mungedSorting.contains("m=video 9 UDP/TLS/RTP/SAVPF 97 96"))
    }

    @Test func testSignalingClientBasics() async {
        let client = GFNSignalingClient(
            signalingUrl: "wss://localhost/nvst/",
            sessionId: "sess-abc",
            serverIp: "127.0.0.1",
            resolution: "1920x1080"
        )
        
        #expect(client.connectedHost == "")
        #expect(client.resolvedIPs.isEmpty)

        // Call public APIs when not connected (should not crash)
        client.sendAnswer(sdp: "v=0...")
        client.sendICECandidate(candidate: "candidate...", sdpMid: "video", sdpMLineIndex: 0)
        client.requestKeyframe()
        client.disconnect()
    }
}

class MockDataChannelSender: DataChannelSender {
    var sentPackets = [Data]()
    func sendData(_ data: Data) {
        sentPackets.append(data)
    }
}

