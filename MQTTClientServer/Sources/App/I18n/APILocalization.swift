//
//  APILocalization.swift
//  MQTTClientServer
//
//  `_t("中文主键", comment:)`：查表主键为中文；`zh.json` / `en.json` 的 **key 均为该中文**，value 分别为中文/英文展示文案，便于导出给翻译。
//  语言由 ``APILanguageMiddleware`` 根据 `Accept-Language` / `?lang=` 写入 ``APII18n/language``。
//

import Foundation
import HTTPTypes
import Hummingbird

// MARK: - 当前请求语言（Task-local）

enum APII18n {
    /// 未走 HTTP 中间件时（如单元测试）默认为中文
    @TaskLocal public static var language: APILanguage = .zh
}

enum APILanguage: String, Sendable {
    case zh
    case en

    /// `?lang=en` / `?lang=zh` 优先；否则解析 `Accept-Language` 首个语言标签
    static func resolve(from request: Request) -> APILanguage {
        let qp = request.uri.queryParameters
        if let raw = qp["lang"] {
            let v = String(raw).lowercased()
            if v == "en" || v.hasPrefix("en-") { return .en }
            if v == "zh" || v.hasPrefix("zh-") { return .zh }
        }

        guard let accept = request.headers[.acceptLanguage], !accept.isEmpty else {
            return .zh
        }
        let first = accept.split(separator: ",").first.map(String.init) ?? accept
        let tag = first.split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } ?? ""
        if tag.hasPrefix("en") { return .en }
        if tag.hasPrefix("zh") { return .zh }
        return .zh
    }
}

// MARK: - 从 Bundle 加载 JSON 表

private enum APITranslationStore: Sendable {
    private static var zhTable: [String: String] = [:]
    private static var enTable: [String: String] = [:]
    private static var loaded = false
    private static let loadLock = NSLock()

    static func string(key: String, language: APILanguage) -> String {
        loadLock.lock()
        defer { loadLock.unlock() }
        if !loaded {
            zhTable = loadJSON(name: "zh")
            enTable = loadJSON(name: "en")
            loaded = true
        }
        let primary = language == .zh ? zhTable : enTable
        let fallback = language == .zh ? enTable : zhTable
        if let v = primary[key], !v.isEmpty { return v }
        if let v = fallback[key], !v.isEmpty { return v }
        return key
    }

    private static func loadJSON(name: String) -> [String: String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            return [:]
        }
        guard let data = try? Data(contentsOf: url),
              let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: String]
        else {
            return [:]
        }
        return dict
    }
}

// MARK: - 对外 API

/// 按 **中文主键** 取当前请求语言的文案；`comment` 与 `NSLocalizedString` 用法一致（文档/导出），不参与查表。
/// 占位符：`_t("未找到 id=%lld 的设备")` 再 `String(format:_t(...), id)`，`zh.json`/`en.json` 中该 key 的 value 须含相同格式占位符。
@inline(__always)
func _t(_ key: String, comment: String = "") -> String {
    _ = comment
    return APITranslationStore.string(key: key, language: APII18n.language)
}
