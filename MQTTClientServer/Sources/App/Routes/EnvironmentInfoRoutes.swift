//
//  EnvironmentInfoRoutes.swift
//  MQTTClientServer
//
//  GET /home_climate/records?start_date=2026-04-29T12:20:16+08:00&end_date=2026-04-29T16:55:16+08:00&location_id=3&sensor_type=3
//  `sensor_type` 可选；不传则按 sensor_type = 3 过滤。
//  GET /home_climate/current?sensor_type=3&location_id=3 — 最近 30 分钟内最新一条；无则湿度/温度/时间为空串。
//  （若网关按表单规则把 `+` 解析成空格，服务端会将 `T… HH:MM` 规范化回 `T…+HH:MM` 再解析）
//

import Fluent
import Foundation
import Hummingbird

/// 居室气候历史：`environment_readings` 按时间与房间筛选。
struct EnvironmentInfoRoutes {
    let dbManager: DatabaseManager

    /// 与约定示例一致：固定展示用东八区标签（与 `time` 字段所用时区一致）。
    private static let responseTimeZoneID = "UTC+08:00"
    private static let responseTimeZone = TimeZone(secondsFromGMT: 8 * 3600)!

    struct HomeClimateRecordsPayload: Encodable {
        let records: [HomeClimateRecordRow]
        let timezone: String
    }

    struct HomeClimateRecordRow: Encodable {
        let hum: String
        let temp: String
        let time: String
    }

    /// 当前读数（`home_climate/current`）；无最近数据时字段为空串。
    struct HomeClimateCurrentPayload: Encodable {
        let humidity: String
        let temperature: String
        let time_sensor: String
    }

    private static let currentRecentInterval: TimeInterval = 30 * 60

    func addRoutes(to router: Router<some RequestContext>) {
        router.get("home_climate/records") { request, _ -> UnifiedAPIResponse<HomeClimateRecordsPayload> in
            let qp = request.uri.queryParameters

            func stringParam(_ key: Substring) -> String? {
                guard let raw = qp[key] else { return nil }
                let s = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }

            guard let startRaw = stringParam("start_date"[...]),
                  let endRaw = stringParam("end_date"[...]),
                  let locationRaw = stringParam("location_id"[...])
            else {
                return .failure(
                    code: .badRequest,
                    message: _t("缺少参数 start_date、end_date 或 location_id", comment: "home_climate records query"),
                    data: HomeClimateRecordsPayload(records: [], timezone: Self.responseTimeZoneID)
                )
            }

            guard let locationId = Int(locationRaw) else {
                return .failure(
                    code: .badRequest,
                    message: _t("location_id 必须为整数", comment: "home_climate records query"),
                    data: HomeClimateRecordsPayload(records: [], timezone: Self.responseTimeZoneID)
                )
            }

            let sensorTypeId: Int
            if let rawSensorType = stringParam("sensor_type"[...]) {
                guard let parsed = Int(rawSensorType) else {
                    return .failure(
                        code: .badRequest,
                        message: _t("sensor_type 必须为整数", comment: "home_climate records query"),
                        data: HomeClimateRecordsPayload(records: [], timezone: Self.responseTimeZoneID)
                    )
                }
                sensorTypeId = parsed
            } else {
                sensorTypeId = 3
            }

            guard let startDate = Self.parseISO8601(Self.normalizeQueryDateTime(startRaw)),
                  let endDate = Self.parseISO8601(Self.normalizeQueryDateTime(endRaw))
            else {
                return .failure(
                    code: .badRequest,
                    message: _t("start_date 或 end_date 不是合法的 ISO8601 时间", comment: "home_climate records query"),
                    data: HomeClimateRecordsPayload(records: [], timezone: Self.responseTimeZoneID)
                )
            }

            let rangeStart = min(startDate, endDate)
            let rangeEnd = max(startDate, endDate)

            let db = dbManager.db()

            do {
                let rows = try await EnvironmentReadings.query(on: db)
                    .filter(\.$location.$id == locationId)
                    .filter(\.$sensorType == sensorTypeId)
                    .filter(\.$createdAt >= rangeStart)
                    .filter(\.$createdAt <= rangeEnd)
                    .sort(\.$createdAt, .ascending)
                    .limit(10_000)
                    .all()

                let timeFormatter = DateFormatter()
                timeFormatter.locale = Locale(identifier: "en_US_POSIX")
                timeFormatter.dateFormat = "HH:mm"
                timeFormatter.timeZone = Self.responseTimeZone

                let records: [HomeClimateRecordRow] = rows.map { row in
                    HomeClimateRecordRow(
                        hum: Self.formatFixedTwo(row.humidity),
                        temp: Self.formatFixedTwo(row.temperature),
                        time: timeFormatter.string(from: row.createdAt)
                    )
                }

                return .success(HomeClimateRecordsPayload(records: records, timezone: Self.responseTimeZoneID))
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: HomeClimateRecordsPayload(records: [], timezone: Self.responseTimeZoneID)
                )
            }
        }

        router.get("home_climate/current") { request, _ -> UnifiedAPIResponse<HomeClimateCurrentPayload> in
            let qp = request.uri.queryParameters

            func stringParam(_ key: Substring) -> String? {
                guard let raw = qp[key] else { return nil }
                let s = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }

            let emptyCurrent = HomeClimateCurrentPayload(humidity: "", temperature: "", time_sensor: "")

            guard let locationRaw = stringParam("location_id"[...]) else {
                return .failure(
                    code: .badRequest,
                    message: _t("缺少参数 location_id", comment: "home_climate current query"),
                    data: emptyCurrent
                )
            }

            guard let locationId = Int(locationRaw) else {
                return .failure(
                    code: .badRequest,
                    message: _t("location_id 必须为整数", comment: "home_climate current query"),
                    data: emptyCurrent
                )
            }

            let sensorTypeId: Int
            if let rawSensorType = stringParam("sensor_type"[...]) {
                guard let parsed = Int(rawSensorType) else {
                    return .failure(
                        code: .badRequest,
                        message: _t("sensor_type 必须为整数", comment: "home_climate current query"),
                        data: emptyCurrent
                    )
                }
                sensorTypeId = parsed
            } else {
                sensorTypeId = 3
            }

            let db = dbManager.db()
            let cutoff = Date().addingTimeInterval(-Self.currentRecentInterval)

            do {
                let row = try await EnvironmentReadings.query(on: db)
                    .filter(\.$location.$id == locationId)
                    .filter(\.$sensorType == sensorTypeId)
                    .filter(\.$createdAt >= cutoff)
                    .sort(\.$createdAt, .descending)
                    .first()

                guard let row else {
                    return .success(emptyCurrent)
                }

                let payload = HomeClimateCurrentPayload(
                    humidity: Self.formatMetricString(row.humidity),
                    temperature: Self.formatMetricString(row.temperature),
                    time_sensor: Self.formatSensorTime(row.createdAt)
                )
                return .success(payload)
            } catch {
                return .failure(
                    code: .internalServerError,
                    message: String(describing: error),
                    data: emptyCurrent
                )
            }
        }
    }

    private static func formatFixedTwo(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.2f", value)
    }

    /// `current` 接口：有值则两位小数，无值则空串。
    private static func formatMetricString(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.2f", value)
    }

    /// 传感器时间：东八区、形如 `2026-04-29T12:30:47+08:00`。
    private static func formatSensorTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = responseTimeZone
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
        return f.string(from: date)
    }

    /// 处理查询串里东八区偏移：`application/x-www-form-urlencoded` 常把未编码的 `+` 变成空格，例如 `…16 08:00` → `…16+08:00`。
    private static func normalizeQueryDateTime(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let re = try? NSRegularExpression(pattern: #"^(.*T\d{2}:\d{2}:\d{2})\s+(\d{2}:\d{2})$"#),
              let match = re.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              match.numberOfRanges == 3,
              let r1 = Range(match.range(at: 1), in: trimmed),
              let r2 = Range(match.range(at: 2), in: trimmed)
        else {
            return trimmed
        }
        return "\(trimmed[r1])+\(trimmed[r2])"
    }

    private static func parseISO8601(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: trimmed) { return d }

        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        if let d = f2.date(from: trimmed) { return d }

        let f3 = ISO8601DateFormatter()
        f3.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime, .withTimeZone]
        if let d = f3.date(from: trimmed) { return d }

        return nil
    }
}
