//
//  MQTTCommandRoutes.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/10.
//

import Foundation
import Logging
import Hummingbird

/// POST /commands  →  通过 MQTT 推送指令给设备
struct MQTTCommandRoutes {
    let mqttService: MQTTService
    let logger = Logger(label: "Routes")

    struct MQTTRequest: Decodable {
        let topic: String
        let payload: String
    }

    struct MQTTCommandData: Encodable {
        let topic: String
        let publish_status: String
    }

    struct MQTTPlainTextData: Encodable {
        let text: String
    }

    struct MQTTRestartData: Encodable {
        let result: String
    }

    struct MQTTServiceStatusData: Encodable {
        let listening: Bool
        let subscribe_ack: String?
        let client_id: String
        let subscribed_topics: [String]
        let received_messages: Int
        let last_message_topic: String?
        let last_message_at: String?
        let online_devices: Int?
        let total_devices: Int?
    }

    struct MQTTDevicesOnlineData: Encodable {
        let online_devices: Int
    }

    struct MQTTBrokerStatusData: Encodable {
        let listening: Bool
        let client_id: String
        let subscribed_topics: [String]
        let received_messages: Int
        let connected_clients: Int?
        let total_clients: Int?
        let broker_messages_received: Int?
        let broker_uptime: String?
        let last_sys_message_at: String?
        let sys_metrics: [String: String]
    }

    func addRoutes(to router: Router<some RequestContext>) {
        router.post("commands") { request, context -> UnifiedAPIResponse<MQTTCommandData> in
            let cmd = try await request.decode(as: MQTTRequest.self, context: context)
            do {
                try await mqttService.publish(topic: cmd.topic, payload: cmd.payload)
                return .success(MQTTCommandData(topic: cmd.topic, publish_status: "published"))
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: MQTTCommandData(topic: cmd.topic, publish_status: "failed")
                )
            }
        }

        router.get("mqtt_health") { _, _ -> UnifiedAPIResponse<MQTTPlainTextData> in
            .success(MQTTPlainTextData(text: "OK"))
        }

        router.get("mqtt_status") { _, _ -> UnifiedAPIResponse<MQTTPlainTextData> in
            let status = await mqttService.listenerStatus()
            return .success(MQTTPlainTextData(text: status))
        }

        router.get("mqtt_service_status") { _, _ -> UnifiedAPIResponse<MQTTServiceStatusData> in
            let status = await mqttService.serviceStatus()
            return .success(
                MQTTServiceStatusData(
                    listening: status.isListening,
                    subscribe_ack: status.subscribeAck,
                    client_id: status.clientId,
                    subscribed_topics: status.subscribedTopics,
                    received_messages: status.receivedMessages,
                    last_message_topic: status.lastMessageTopic,
                    last_message_at: status.lastMessageAtISO8601,
                    online_devices: status.onlineDevices,
                    total_devices: status.totalDevices
                )
            )
        }

        router.get("mqtt_devices_online") { _, _ -> UnifiedAPIResponse<MQTTDevicesOnlineData> in
            if let onlineCount = await mqttService.onlineDevicesCount() {
                return .success(MQTTDevicesOnlineData(online_devices: onlineCount))
            }
            return .failure(
                code: .serviceUnavailable,
                message: "Database unavailable for online device count",
                data: MQTTDevicesOnlineData(online_devices: 0)
            )
        }

        router.get("mqtt_broker_status") { _, _ -> UnifiedAPIResponse<MQTTBrokerStatusData> in
            let status = await mqttService.brokerStatus()
            return .success(
                MQTTBrokerStatusData(
                    listening: status.isListening,
                    client_id: status.clientId,
                    subscribed_topics: status.subscribedTopics,
                    received_messages: status.receivedMessages,
                    connected_clients: status.connectedClients,
                    total_clients: status.totalClients,
                    broker_messages_received: status.receivedMessagesOnBroker,
                    broker_uptime: status.brokerUptime,
                    last_sys_message_at: status.lastSysMessageAtISO8601,
                    sys_metrics: status.sysMetrics
                )
            )
        }

        router.post("mqtt_restart") { _, _ -> UnifiedAPIResponse<MQTTRestartData> in
            await mqttService.restartListener()
            return .success(MQTTRestartData(result: "restarted"))
        }
    }
}
