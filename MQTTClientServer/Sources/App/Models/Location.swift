//
//  Location.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/18.
//

import Foundation
import Fluent

/**
| id | name        | code       | parent | type |  sortOrder |
| -- | ----------- | ---------- | ------ | ---- | ---- |
| 1  | Home        | home       | NULL   | home | 0 |
| 2  | Office      | offic      | NULL   | home | 0 |
| 3  | Living Room | livingroom | 1      | room | 1 |
| 4  | Bedroom     | bedroom    | 1      | room | 1 |
*/

/// 空间/位置树节点，对应表 `location`，用于匹配 `location_id` 等
final class Location: Model, @unchecked Sendable {

    static let schema = "location"

    @ID(custom: "id", generatedBy: .database)
    var id: Int?

    @Field(key: "name")
    var name: String

    @Field(key: "code")
    var code: String

    @OptionalField(key: "parent_id")
    var parentId: Int?

    /// 列名为 SQL 常用字段名 `type`，Swift 侧避免与 `Swift.type(of:)` 等混淆
    @Field(key: "type")
    var locationType: String

    /// 列名为 SQL 保留字 `description`，Swift 侧避免与 `CustomStringConvertible.description` 冲突
    @OptionalField(key: "description")
    var locationDescription: String?

    @Field(key: "sort_order")
    var sortOrder: Int

    @Field(key: "is_active")
    var isActive: Bool

    @OptionalField(key: "mqtt_topic_prefix")
    var mqttTopicPrefix: String?

    @OptionalField(key: "latitude")
    var latitude: Double?

    @OptionalField(key: "longitude")
    var longitude: Double?

    @OptionalField(key: "address")
    var address: String?

    @OptionalField(key: "timezone")
    var timezone: String?

    @OptionalField(key: "created_at")
    var createdAt: Date?

    @OptionalField(key: "updated_at")
    var updatedAt: Date?

    init() {}
}
