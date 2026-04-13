//
//  StatusRoutes.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/13.
//

import Foundation

import Foundation
import Hummingbird

struct StatusRoutes {
    
    // 请求体结构
    struct StatusRequest: Decodable {
        let status: String
    }

    // 响应结构
    struct StatusResponse: ResponseEncodable {
        let status: Bool
        let message: String
    }
    
    func addRoutes(to router: Router<some RequestContext>) {
        router.get("status") { request, context -> StatusResponse in
            let cmd = try await request.decode(as: StatusRequest.self, context: context)
            return StatusResponse(status: true, message: "Server is running")
        }
        
        // 健康检查
        router.get("health") { _, _ in
            return Response(status: .ok, body: .init(byteBuffer: .init(string: "OK")))
        }
    }
}
