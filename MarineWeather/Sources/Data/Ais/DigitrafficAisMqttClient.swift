import CocoaMQTT
import CocoaMQTTWebSocket
import Foundation
import os

/// Digitraffic AIS MQTT over WebSockets (CocoaMQTT).
@MainActor
final class DigitrafficAisMqttClient: NSObject {
    private let log = Logger(subsystem: "fi.veneappi.MarineWeather", category: "DigitrafficAisMqtt")
    private var mqtt: CocoaMQTT?
    private var messageContinuation: AsyncStream<AisMqttInboundMessage>.Continuation?
    private var stateContinuation: AsyncStream<AisMqttConnectionState>.Continuation?

    private(set) var connectionState: AisMqttConnectionState = .disconnected

    private(set) lazy var messages: AsyncStream<AisMqttInboundMessage> = {
        AsyncStream(bufferingPolicy: .bufferingNewest(512)) { continuation in
            messageContinuation = continuation
        }
    }()

    private(set) lazy var connectionStates: AsyncStream<AisMqttConnectionState> = {
        AsyncStream { continuation in
            stateContinuation = continuation
            continuation.yield(connectionState)
        }
    }()

    var isConnected: Bool { mqtt?.connState == .connected }

    func connect() async throws {
        if isConnected {
            setConnectionState(.connected)
            return
        }
        setConnectionState(.connecting)

        if let existing = mqtt, existing.connState != .connected {
            existing.disconnect()
            mqtt = nil
        }

        let clientID = "marine-weather-ios-\(String(format: "%x", Int.random(in: 0..<Int.max)))"
        let websocket = CocoaMQTTWebSocket(uri: "/mqtt")
        websocket.enableSSL = true

        let client = CocoaMQTT(
            clientID: clientID,
            host: "meri.digitraffic.fi",
            port: 443,
            socket: websocket
        )
        client.username = AisMqttConfig.username
        client.password = AisMqttConfig.password
        client.autoReconnect = true
        client.autoReconnectTimeInterval = UInt16(AisMqttConfig.reconnectPeriodMs / 1000)
        client.keepAlive = 60
        client.delegate = self
        mqtt = client

        let connected = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let resumeLock = NSLock()
            var resumed = false
            func resumeOnce(_ value: Bool) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: value)
            }

            client.didConnectAck = { _, ack in
                resumeOnce(ack == .accept)
            }
            client.didDisconnect = { _, _ in
                resumeOnce(false)
            }
            if !client.connect(timeout: Double(AisMqttConfig.connectTimeoutMs) / 1000.0) {
                resumeOnce(false)
            }
        }

        if connected {
            setConnectionState(.connected)
            log.info("connected")
        } else {
            setConnectionState(.error)
            log.warning("connect failed")
            throw AisMqttClientError.connectFailed
        }
    }

    func disconnect() {
        mqtt?.disconnect()
        mqtt = nil
        setConnectionState(.disconnected)
    }

    func subscribeVessel(mmsi: Int) {
        guard isConnected, let mqtt else { return }
        _ = mqtt.subscribe(AisMqttConfig.locationTopic(mmsi: mmsi), qos: .qos1)
        _ = mqtt.subscribe(AisMqttConfig.metadataTopic(mmsi: mmsi), qos: .qos1)
    }

    func unsubscribeVessel(mmsi: Int) {
        guard isConnected, let mqtt else { return }
        mqtt.unsubscribe(AisMqttConfig.locationTopic(mmsi: mmsi))
        mqtt.unsubscribe(AisMqttConfig.metadataTopic(mmsi: mmsi))
    }

    private func setConnectionState(_ state: AisMqttConnectionState) {
        connectionState = state
        stateContinuation?.yield(state)
    }

    private func emitMessage(topic: String, payload: Data) {
        guard !payload.isEmpty else { return }
        messageContinuation?.yield(AisMqttInboundMessage(topic: topic, payload: payload))
    }
}

extension DigitrafficAisMqttClient: CocoaMQTTDelegate {
    nonisolated func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        Task { @MainActor in
            if ack == .accept {
                setConnectionState(.connected)
                log.info("connected (delegate)")
            } else {
                setConnectionState(.error)
            }
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        Task { @MainActor in
            switch state {
            case .connected:
                setConnectionState(.connected)
            case .connecting:
                setConnectionState(.connecting)
            case .disconnected:
                setConnectionState(.disconnected)
            }
        }
    }

    nonisolated func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        Task { @MainActor in
            setConnectionState(.disconnected)
            if let err {
                log.warning("disconnected: \(err.localizedDescription, privacy: .public)")
            } else {
                log.info("disconnected")
            }
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        let topic = message.topic
        let payload = Data(message.payload)
        Task { @MainActor in
            emitMessage(topic: topic, payload: payload)
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        if !failed.isEmpty {
            Task { @MainActor in
                log.warning("subscribe failed for \(failed.count) topics")
            }
        }
    }

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}

    nonisolated func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}

    nonisolated func mqttDidPing(_ mqtt: CocoaMQTT) {}

    nonisolated func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}

    nonisolated func mqttUrlSession(
        _ mqtt: CocoaMQTT,
        didReceiveTrust trust: SecTrust,
        didReceiveChallenge challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

enum AisMqttClientError: Error {
    case connectFailed
}
