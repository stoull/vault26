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
    
    // 请求体结构
    struct MQTTRequest: Decodable {
        let topic: String    // e.g. "devices/light01/cmd"
        let payload: String  // e.g. "{\"action\":\"on\"}"
    }

    // 响应结构
    struct MQTTCommandResponse: ResponseEncodable {
        let status: String
        let topic: String
    }


    func addRoutes(to router: Router<some RequestContext>) {
        
        router.post("commands") { request, context -> MQTTCommandResponse in
            
            let cmd = try await request.decode(as: MQTTRequest.self, context: context)
            try await mqttService.publish(topic: cmd.topic, payload: cmd.payload)
            let resp = MQTTCommandResponse(status: "published", topic: cmd.topic)
            // Hummingbird 会自动将 MQTTCommandResponse <ResponseEncodable> 编码为 JSON 并设置 Content-Type
            return resp
        }

        // 健康检查
        router.get("mqtt_health") { _, _ in
            return Response(status: .ok, body: .init(byteBuffer: .init(string: "OK")))
        }

        // 运行时诊断：返回 listener 状态和最近一次 subscribe ack
        router.get("mqtt_status") { _, _ in
            let status = await mqttService.listenerStatus()
            return Response(status: .ok, body: .init(byteBuffer: .init(string: status)))
        }

        // 允许远程重启 listener（运维用）
        router.post("mqtt_restart") { _, _ in
            await mqttService.restartListener()
            return Response(status: .ok, body: .init(byteBuffer: .init(string: "restarted")))
        }
    }
}
