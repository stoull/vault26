//
//  SeedLocation.swift
//  MQTTClientServer
//
//  幂等写入常用 `location` 树（根节点 `home` + 常见房间）；依赖 `CreateLocation`。
//

import Foundation
import Fluent

struct SeedLocation: AsyncMigration {
    var name: String { "SeedLocation" }

    /// 父节点须先于子节点插入；`parentCode == nil` 表示根
    private struct Row {
        let code: String
        let name: String
        let parentCode: String?
        let locationType: String
        let sortOrder: Int
    }

    private static let rows: [Row] = [
        Row(code: "unassigned", name: "Unassigned", parentCode: nil, locationType: "unassigned", sortOrder: 0),
        Row(code: "home", name: "Home", parentCode: nil, locationType: "home", sortOrder: 1),
        Row(code: "livingroom", name: "客厅", parentCode: "home", locationType: "room", sortOrder: 1),
        Row(code: "bedroom", name: "卧室", parentCode: "home", locationType: "room", sortOrder: 2),
        Row(code: "kitchen", name: "厨房", parentCode: "home", locationType: "room", sortOrder: 3),
        Row(code: "bathroom", name: "卫生间", parentCode: "home", locationType: "room", sortOrder: 4),
        Row(code: "balcony", name: "阳台", parentCode: "home", locationType: "room", sortOrder: 5),
        Row(code: "study", name: "书房", parentCode: "home", locationType: "room", sortOrder: 6),
        Row(code: "office", name: "办公室", parentCode: "home", locationType: "room", sortOrder: 7),
        Row(code: "garage", name: "车库", parentCode: "home", locationType: "room", sortOrder: 8),
        Row(code: "laboratory", name: "实验室", parentCode: "home", locationType: "room", sortOrder: 9),

        Row(code: "fridge", name: "冰箱", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "fridge_refrigerator", name: "冰箱-冷藏层", parentCode: "fridge", locationType: "device", sortOrder: 1),
        Row(code: "fridge_freezer", name: "冰箱-冷冻层", parentCode: "fridge", locationType: "device", sortOrder: 1),
        Row(code: "washing_machine", name: "洗衣机", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "washing_machine_top", name: "洗衣机-上层", parentCode: "washing_machine", locationType: "device", sortOrder: 1),
        Row(code: "washing_machine_bottom", name: "洗衣机-下层", parentCode: "washing_machine", locationType: "device", sortOrder: 1),
        Row(code: "tv", name: "电视", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "air_conditioner", name: "空调", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "fan", name: "风扇", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "curtain", name: "窗帘", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "door", name: "门", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "window", name: "窗户", parentCode: "livingroom", locationType: "device", sortOrder: 1),
        Row(code: "wall", name: "墙", parentCode: "livingroom", locationType: "device", sortOrder: 1),

        Row(code: "outdoor", name: "室外", parentCode: "home", locationType: "home", sortOrder: 9),
        Row(code: "outdoor_east", name: "室外-东", parentCode: "home", locationType: "home", sortOrder: 9),
        Row(code: "outdoor_west", name: "室外-西", parentCode: "home", locationType: "home", sortOrder: 9),
        Row(code: "outdoor_north", name: "室外-北", parentCode: "home", locationType: "home", sortOrder: 9),
        Row(code: "outdoor_south", name: "室外-南", parentCode: "home", locationType: "home", sortOrder: 9),
        Row(code: "outdoor_top", name: "室外-顶部", parentCode: "home", locationType: "home", sortOrder: 9),
    ]

    /// 子节点先于根删除，避免残留孤儿行
    private static var seededCodesForRevert: [String] {
        let roots = rows.filter { $0.parentCode == nil }.map(\.code)
        let children = rows.filter { $0.parentCode != nil }.map(\.code)
        return children.reversed() + roots
    }

    func prepare(on database: Database) async throws {
        for row in Self.rows {
            if try await Location.query(on: database).filter(\.$code == row.code).first() != nil {
                continue
            }
            var parentId: Int?
            if let pCode = row.parentCode {
                guard let parent = try await Location.query(on: database).filter(\.$code == pCode).first(),
                      let pid = parent.id
                else {
                    throw SeedLocationError.missingParent(code: row.code, parentCode: pCode)
                }
                parentId = pid
            }

            let loc = Location()
            loc.name = row.name
            loc.code = row.code
            loc.parentId = parentId
            loc.locationType = row.locationType
            loc.sortOrder = row.sortOrder
            loc.isActive = true
            try await loc.save(on: database)
        }
    }

    func revert(on database: Database) async throws {
        for code in Self.seededCodesForRevert {
            try await Location.query(on: database).filter(\.$code == code).delete()
        }
    }

    private enum SeedLocationError: Error, CustomStringConvertible {
        case missingParent(code: String, parentCode: String)

        var description: String {
            switch self {
            case .missingParent(let code, let parent):
                return "SeedLocation: cannot insert code=\(code), parent code=\(parent) not found"
            }
        }
    }
}
