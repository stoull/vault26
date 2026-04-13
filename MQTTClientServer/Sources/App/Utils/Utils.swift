//
//  Utils.swift
//  MQTTClientServer
//
//  Created by Hut on 2026/4/13.
//

import Foundation

/// 将设备上报的 ISO8601 字符串转换为 MySQL TIMESTAMP(3) 字符串（UTC，带毫秒）
/// 返回值示例："2025-12-09 08:00:00.123"
func iso8601ToMySQLTimestamp3(_ iso: String) -> String? {
    // 优先使用 ISO8601DateFormatter 以兼容带时区与小数秒的 ISO 格式
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var date: Date? = isoFormatter.date(from: iso)

    // 如果上面失败，尝试不带 fractionalSeconds 的解析（某些设备不带毫秒）
    if date == nil {
        let isoFormatterNoFrac = ISO8601DateFormatter()
        isoFormatterNoFrac.formatOptions = [.withInternetDateTime]
        date = isoFormatterNoFrac.date(from: iso)
    }

    // 额外兜底：尝试一些常见格式（比如没有时区的本地时间），根据设备协议决定是否需要
    if date == nil {
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX", // e.g. 2025-12-09T08:00:00.123+08:00
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",     // e.g. 2025-12-09T08:00:00+08:00
            "yyyy-MM-dd'T'HH:mm:ss.SSS",      // e.g. 2025-12-09T08:00:00.123 (no tz)
            "yyyy-MM-dd'T'HH:mm:ss",          // e.g. 2025-12-09T08:00:00 (no tz)
            "yyyy-MM-dd HH:mm:ss"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        for fmt in fallbackFormats {
            df.dateFormat = fmt
            // 假设没有时区的字符串为设备本地时间或直接当作 UTC（你需要根据设备协议选择）
            df.timeZone = TimeZone(secondsFromGMT: 0) // 这里假设 UTC；若设备为本地时间可改为本地时区
            // df.timeZone = TimeZone(identifier: "Asia/Shanghai")
            if let d = df.date(from: iso) {
                date = d
                break
            }
        }
    }

    guard let finalDate = date else {
        return nil
    }

    // 输出为 MySQL 可接受的格式（UTC，带毫秒）
    let outFormatter = DateFormatter()
    outFormatter.locale = Locale(identifier: "en_US_POSIX")
    outFormatter.timeZone = TimeZone(abbreviation: "UTC") // 强制 UTC
    outFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"  // 支持 TIMESTAMP(3) 或 DATETIME(3)

    return outFormatter.string(from: finalDate)
}

/// 将设备上报的 ISO8601 字符串转换为 MySQL 可接受的无毫秒时间字符串（UTC）
/// 返回值示例："2025-12-09 08:30:00"
func iso8601ToMySQLTimestampNoMillis(_ iso: String) -> String? {
    // 优先使用 ISO8601DateFormatter，支持带/不带小数秒和时区
    let isoWithFrac = ISO8601DateFormatter()
    isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var date: Date? = isoWithFrac.date(from: iso)

    // 回退到不带 fractionalSeconds 的解析
    if date == nil {
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]
        date = isoNoFrac.date(from: iso)
    }

    // 兜底：尝试常见格式（视设备实际输出决定是否需要）
    if date == nil {
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        // 这里把无时区字符串当作 UTC 处理；如果设备文档说明为本地时间，请改为相应时区
        df.timeZone = TimeZone(secondsFromGMT: 0)
        // df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for fmt in fallbackFormats {
            df.dateFormat = fmt
            if let d = df.date(from: iso) {
                date = d
                break
            }
        }
    }

    guard let finalDate = date else {
        return nil
    }

    // 输出为 MySQL DATETIME/TIMESTAMP 不带毫秒格式（UTC）
    let outFormatter = DateFormatter()
    outFormatter.locale = Locale(identifier: "en_US_POSIX")
    outFormatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
    outFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"     // 无毫秒

    return outFormatter.string(from: finalDate)
}

/// 将设备上报的 ISO8601 字符串转换为 MySQL 可接受的无毫秒时间字符串（UTC）
/// 返回值示例："2025-12-09 08:30:00"
func iso8601ToMySQLTimestampNoMillisToDate(_ iso: String) -> Date? {
    // 优先使用 ISO8601DateFormatter，支持带/不带小数秒和时区
    let isoWithFrac = ISO8601DateFormatter()
    isoWithFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var date: Date? = isoWithFrac.date(from: iso)

    // 回退到不带 fractionalSeconds 的解析
    if date == nil {
        let isoNoFrac = ISO8601DateFormatter()
        isoNoFrac.formatOptions = [.withInternetDateTime]
        date = isoNoFrac.date(from: iso)
    }

    // 兜底：尝试常见格式（视设备实际输出决定是否需要）
    if date == nil {
        let fallbackFormats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        // 这里把无时区字符串当作 UTC 处理；如果设备文档说明为本地时间，请改为相应时区
        df.timeZone = TimeZone(secondsFromGMT: 0)
        // df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for fmt in fallbackFormats {
            df.dateFormat = fmt
            if let d = df.date(from: iso) {
                date = d
                break
            }
        }
    }

    guard let finalDate = date else {
        return nil
    }

    return finalDate
}
