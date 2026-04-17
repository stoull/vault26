//
//  UnifiedAPIResponse.swift
//  MQTTClientServer
//
//  所有 HTTP JSON 接口的统一响应外壳
//

import Foundation
import Hummingbird

// MARK: - 常用业务码（与 HTTP 语意对齐，写入 JSON 的 `code` 字段）

/// 统一 API 业务码，便于与前端约定；**不等于**必须设置同名 HTTP 状态行。
enum APIBusinessCode: Int, Sendable, Codable {
    /// 成功（与 ``UnifiedAPIResponse/success(_:message:)`` 默认一致）
    case success = 200

    /// 参数错误、缺字段、格式非法
    case badRequest = 400
    /// 未登录 / token 无效
    case unauthorized = 401
    /// 无权限
    case forbidden = 403
    /// 资源不存在
    case notFound = 404
    /// 资源冲突（如唯一键重复）
    case conflict = 409
    /// 语义正确但业务规则不允许（校验失败等）
    case unprocessableEntity = 422
    /// 限流
    case tooManyRequests = 429

    /// 服务端内部错误
    case internalServerError = 500
    /// 网关/上游异常
    case badGateway = 502
    /// 服务暂不可用
    case serviceUnavailable = 503
}

extension APIBusinessCode {
    /// 与业务码对应的默认说明（受 ``APII18n/language`` 影响）；`failure` 在 `message` 为空时使用
    var defaultMessage: String {
        switch self {
        case .success:
            return _t("操作成功", comment: "Default message for API business code success")
        case .badRequest:
            return _t("请求参数错误", comment: "Default message for HTTP 400 style business code")
        case .unauthorized:
            return _t("未授权或登录已失效", comment: "Default message for 401")
        case .forbidden:
            return _t("没有权限执行此操作", comment: "Default message for 403")
        case .notFound:
            return _t("请求的资源不存在", comment: "Default message for 404")
        case .conflict:
            return _t("资源冲突，请检查是否重复提交", comment: "Default message for 409")
        case .unprocessableEntity:
            return _t("请求无法通过业务校验", comment: "Default message for 422")
        case .tooManyRequests:
            return _t("请求过于频繁，请稍后再试", comment: "Default message for 429")
        case .internalServerError:
            return _t("服务器内部错误", comment: "Default message for 500")
        case .badGateway:
            return _t("网关或上游服务异常", comment: "Default message for 502")
        case .serviceUnavailable:
            return _t("服务暂时不可用，请稍后再试", comment: "Default message for 503")
        }
    }

    /// 已知业务码返回本地化默认说明，否则返回通用失败文案
    static func resolvedFailureMessage(code: Int, explicitMessage: String) -> String {
        let trimmed = explicitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return explicitMessage
        }
        return APIBusinessCode(rawValue: code)?.defaultMessage
            ?? _t("请求失败", comment: "Fallback when business code is unknown")
    }
}

// MARK: - 统一响应体

/// 统一格式：`code`、`data`、`message`、`success`、`timestamp`
struct UnifiedAPIResponse<Payload: Encodable>: ResponseEncodable, Encodable {
    let code: Int
    let data: Payload
    let message: String
    let success: Bool
    let timestamp: String

    init(code: Int, data: Payload, message: String, success: Bool, timestamp: String) {
        self.code = code
        self.data = data
        self.message = message
        self.success = success
        self.timestamp = timestamp
    }

    /// 成功：默认 `code = 200`、`success = true`；`message` 为空或仅空白时使用本地化「操作成功」
    static func success(_ data: Payload, message: String = "") -> Self {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? _t("操作成功", comment: "Default success message for UnifiedAPIResponse") : message
        return Self(
            code: APIBusinessCode.success.rawValue,
            data: data,
            message: resolved,
            success: true,
            timestamp: APITimestamp.now()
        )
    }

    /// 失败：`success = false`，`code` 使用 ``APIBusinessCode``。
    /// `message` 为空或仅空白时，使用 ``APIBusinessCode/defaultMessage``。
    static func failure(code: APIBusinessCode, message: String = "", data: Payload) -> Self {
        let resolved: String
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = code.defaultMessage
        } else {
            resolved = message
        }
        return Self(
            code: code.rawValue,
            data: data,
            message: resolved,
            success: false,
            timestamp: APITimestamp.now()
        )
    }

    /// 失败：`success = false`，`code` 为任意整型（扩展码或第三方约定）。
    /// `message` 为空或仅空白时，若 `code` 能映射到 ``APIBusinessCode`` 则用其默认说明，否则为「请求失败」。
    static func failure(code: Int, message: String = "", data: Payload) -> Self {
        Self(
            code: code,
            data: data,
            message: APIBusinessCode.resolvedFailureMessage(code: code, explicitMessage: message),
            success: false,
            timestamp: APITimestamp.now()
        )
    }
}

enum APITimestamp {
    /// 例：`2026-04-17T01:17:51.806867+00:00`（UTC，带小数秒与 `+00:00`）
    static func now() -> String {
        let date = Date()
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [
            .withYear,
            .withMonth,
            .withDay,
            .withTime,
            .withDashSeparatorInDate,
            .withColonSeparatorInTime,
            .withFractionalSeconds,
            .withTimeZone
        ]
        var s = formatter.string(from: date)
        if s.hasSuffix("Z") {
            s.removeLast()
            s.append("+00:00")
        }
        return s
    }
}
