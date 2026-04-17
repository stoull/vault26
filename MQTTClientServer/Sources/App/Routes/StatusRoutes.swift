//
//  StatusRoutes.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/13.
//

import Foundation
import Hummingbird

struct StatusRoutes {

    struct StatusData: Encodable {
        let online: Bool
    }

    struct HealthData: Encodable {
        let ok: Bool
    }

    func addRoutes(to router: Router<some RequestContext>) {
        router.get("status") { _, _ -> UnifiedAPIResponse<StatusData> in
            .success(StatusData(online: true))
        }

        router.get("health") { _, _ -> UnifiedAPIResponse<HealthData> in
            .success(HealthData(ok: true))
        }
    }
}
