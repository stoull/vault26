//
//  SystemDeviceRoutes.swift
//  MQTTClientServer
//
//  SystemDevice 的 JSON API：查询、删除、添加、更新（请求体均为 application/json）
//

import Foundation
import Fluent
import Hummingbird

/// `POST /api/system-devices/*`，请求与响应均为 JSON（外层为 ``UnifiedAPIResponse``）
struct EdgeDeviceRoutes {
    let dbManager: DatabaseManager

    // MARK: - Request DTOs（JSON snake_case）

    struct SystemDeviceAddRequest: Decodable {
        let unique_id: String
        let device_type: Int
        let device_name: String?
        let description: String?
        let location: String?
        let group_name: String?
        let created_at: String?
        let last_seen: String?
        let is_active: Int?
    }

    struct SystemDeviceQueryRequest: Decodable {
        let id: Int?
        let unique_id: String?
        let limit: Int?
    }

    struct SystemDeviceDeleteRequest: Decodable {
        let id: Int
    }

    /// 按 `id` 更新行：仅对 JSON 中出现的非 null 字段写库（未出现的字段保持不变）。
    struct SystemDeviceUpdateRequest: Decodable {
        let id: Int
        let unique_id: String?
        let device_type: Int?
        let device_name: String?
        let description: String?
        let location: String?
        let group_name: String?
        let created_at: String?
        let last_seen: String?
        let is_active: Int?
    }

    // MARK: - Response `data` 载荷

    struct SystemDeviceDTO: Encodable {
        let id: Int
        let unique_id: String
        let device_type: Int
        let device_name: String?
        let description: String?
        let location: String?
        let group_name: String?
        let created_at: String
        let last_seen: String
        let is_active: Int

        init(model: EdgeDevice) throws {
            guard let id = model.id else {
                throw SystemDeviceRouteError.missingModelId
            }
            self.id = id
            self.unique_id = model.uniqueId
            self.device_type = model.deviceType
            self.device_name = model.deviceName
            self.description = model.deviceDescription
            self.location = model.location
            self.group_name = model.groupName
            self.created_at = Self.isoString(model.createdAt)
            self.last_seen = Self.isoString(model.lastSeen)
            self.is_active = model.isActive
        }

        private static func isoString(_ date: Date) -> String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.string(from: date)
        }
    }

    struct SystemDeviceMutationData: Encodable {
        let device: SystemDeviceDTO?
    }

    struct SystemDeviceListData: Encodable {
        let devices: [SystemDeviceDTO]
    }

    private enum SystemDeviceRouteError: Error {
        case missingModelId
    }

    func addRoutes(to router: Router<some RequestContext>) {
        let group = router.group("api/system-devices")

        group.post("add") { request, context -> UnifiedAPIResponse<SystemDeviceMutationData> in
            let body = try await request.decode(as: SystemDeviceAddRequest.self, context: context)
            let db = dbManager.db()

            let now = Date()
            let created = parseISO8601(body.created_at) ?? now
            let lastSeen = parseISO8601(body.last_seen) ?? now
            let active = body.is_active ?? 1

            let device = EdgeDevice()
            device.uniqueId = body.unique_id.trimmingCharacters(in: .whitespacesAndNewlines)
            device.deviceType = body.device_type
            device.deviceName = body.device_name
            device.deviceDescription = body.description
            device.location = body.location
            device.groupName = body.group_name
            device.createdAt = created
            device.lastSeen = lastSeen
            device.isActive = active

            guard !device.uniqueId.isEmpty else {
                return .failure(
                    code: .badRequest,
                    message: _t("unique_id 不能为空", comment: "Validation when unique_id is empty"),
                    data: SystemDeviceMutationData(device: nil)
                )
            }

            do {
                try await device.save(on: db)
                let dto = try SystemDeviceDTO(model: device)
                return .success(SystemDeviceMutationData(device: dto))
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: SystemDeviceMutationData(device: nil)
                )
            }
        }

        group.post("query") { request, context -> UnifiedAPIResponse<SystemDeviceListData> in
            let body = try await request.decode(as: SystemDeviceQueryRequest.self, context: context)
            let db = dbManager.db()

            do {
                let models: [EdgeDevice]
                if let id = body.id {
                    if let one = try await EdgeDevice.find(id, on: db) {
                        models = [one]
                    } else {
                        return .success(
                            SystemDeviceListData(devices: []),
                            message: _t("未找到记录", comment: "Query returned no rows")
                        )
                    }
                } else if let uid = body.unique_id?.trimmingCharacters(in: .whitespacesAndNewlines), !uid.isEmpty {
                    models = try await EdgeDevice.query(on: db)
                        .filter(\.$uniqueId == uid)
                        .all()
                } else {
                    let cap = min(max(body.limit ?? 50, 1), 200)
                    models = try await EdgeDevice.query(on: db)
                        //.sort(\.$id, .descending)
                        .sort(\.$id, .descending)
                        .limit(cap)
                        .all()
                }

                let dtos = try models.map { try SystemDeviceDTO(model: $0) }
                return .success(SystemDeviceListData(devices: dtos))
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: SystemDeviceListData(devices: [])
                )
            }
        }

        group.post("delete") { request, context -> UnifiedAPIResponse<SystemDeviceMutationData> in
            let body = try await request.decode(as: SystemDeviceDeleteRequest.self, context: context)
            let db = dbManager.db()

            do {
                guard let device = try await EdgeDevice.find(body.id, on: db) else {
                    return .failure(
                        code: .notFound,
                        message: String(
                            format: _t("未找到 id=%lld 的设备", comment: "Delete/query device by id not found"),
                            Int64(body.id)
                        ),
                        data: SystemDeviceMutationData(device: nil)
                    )
                }
                let dto = try SystemDeviceDTO(model: device)
                try await device.delete(on: db)
                return .success(SystemDeviceMutationData(device: dto), message: _t("删除成功", comment: "After device deleted"))
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: SystemDeviceMutationData(device: nil)
                )
            }
        }

        group.post("update") { request, context -> UnifiedAPIResponse<SystemDeviceMutationData> in
            let body = try await request.decode(as: SystemDeviceUpdateRequest.self, context: context)
            let db = dbManager.db()

            do {
                guard let device = try await EdgeDevice.find(body.id, on: db) else {
                    return .failure(
                        code: .notFound,
                        message: String(
                            format: _t("未找到 id=%lld 的设备", comment: "Update device by id not found"),
                            Int64(body.id)
                        ),
                        data: SystemDeviceMutationData(device: nil)
                    )
                }

                var touched = false
                if let raw = body.unique_id {
                    let uid = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !uid.isEmpty else {
                        return .failure(
                            code: .badRequest,
                            message: _t("unique_id 不能为空", comment: "Validation when unique_id is empty on update"),
                            data: SystemDeviceMutationData(device: nil)
                        )
                    }
                    device.uniqueId = uid
                    touched = true
                }
                if let v = body.device_type {
                    device.deviceType = v
                    touched = true
                }
                if let v = body.device_name {
                    device.deviceName = v
                    touched = true
                }
                if let v = body.description {
                    device.deviceDescription = v
                    touched = true
                }
                if let v = body.location {
                    device.location = v
                    touched = true
                }
                if let v = body.group_name {
                    device.groupName = v
                    touched = true
                }
                if let raw = body.created_at {
                    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty {
                        guard let d = parseISO8601(raw) else {
                            return .failure(
                                code: .badRequest,
                                message: _t("日期时间格式无效", comment: "created_at on update"),
                                data: SystemDeviceMutationData(device: nil)
                            )
                        }
                        device.createdAt = d
                        touched = true
                    }
                }
                if let raw = body.last_seen {
                    let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !s.isEmpty {
                        guard let d = parseISO8601(raw) else {
                            return .failure(
                                code: .badRequest,
                                message: _t("日期时间格式无效", comment: "last_seen on update"),
                                data: SystemDeviceMutationData(device: nil)
                            )
                        }
                        device.lastSeen = d
                        touched = true
                    }
                }
                if let v = body.is_active {
                    device.isActive = v
                    touched = true
                }

                if touched {
                    try await device.update(on: db)
                }
                let dto = try SystemDeviceDTO(model: device)
                return .success(SystemDeviceMutationData(device: dto), message: _t("更新成功", comment: "After device updated"))
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: SystemDeviceMutationData(device: nil)
                )
            }
        }
    }

    private func parseISO8601(_ s: String?) -> Date? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }
}
