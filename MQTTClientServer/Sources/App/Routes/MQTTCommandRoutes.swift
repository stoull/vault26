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

        router.post("mqtt_restart") { _, _ -> UnifiedAPIResponse<MQTTRestartData> in
            await mqttService.restartListener()
            return .success(MQTTRestartData(result: "restarted"))
        }
    }
}
