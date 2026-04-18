/// MQTT 主题中与 `+` / `#` 相关的匹配与通配段提取（无外部依赖，便于单测）
public enum MQTTTopicPattern {
    /// 匹配 MQTT 主题模式，支持单层通配符 (+) 和多层通配符 (#)
    /// - Parameters:
    ///   - topic: 实际收到的主题，如 "sensor/dht22/1/data"
    ///   - pattern: 订阅模式，如 "sensor/dht22/+/data"
    /// - Returns: 是否匹配
    public static func matchesMQTTPattern(topic: String, pattern: String) -> Bool {
        let topicLevels = topic.split(separator: "/").map(String.init)
        let patternLevels = pattern.split(separator: "/").map(String.init)

        if patternLevels.last == "#" {
            if patternLevels.count - 1 > topicLevels.count {
                return false
            }
            for i in 0..<(patternLevels.count - 1) {
                if patternLevels[i] != "+" && patternLevels[i] != topicLevels[i] {
                    return false
                }
            }
            return true
        }

        guard topicLevels.count == patternLevels.count else {
            return false
        }

        for (topicLevel, patternLevel) in zip(topicLevels, patternLevels) {
            if patternLevel != "+" && patternLevel != topicLevel {
                return false
            }
        }

        return true
    }

    /// 从主题中提取第 `wildcardIndex` 个 `+` 对应位置的段（从 0 计数）。仅当 topic 与 pattern 段数一致且均为 `+` 通配时有效；不支持 `#`。
    /// 例如: `extractFromTopic("sensor/dht22/1/data", pattern: "sensor/dht22/+/data", wildcardIndex: 0)` → `"1"`
    public static func extractFromTopic(_ topic: String, pattern: String, wildcardIndex: Int) -> String? {
        let topicLevels = topic.split(separator: "/").map(String.init)
        let patternLevels = pattern.split(separator: "/").map(String.init)

        guard topicLevels.count == patternLevels.count else {
            return nil
        }

        var wildcardCount = 0
        for (index, patternLevel) in patternLevels.enumerated() {
            if patternLevel == "+" {
                if wildcardCount == wildcardIndex {
                    return topicLevels[index]
                }
                wildcardCount += 1
            }
        }

        return nil
    }
}
