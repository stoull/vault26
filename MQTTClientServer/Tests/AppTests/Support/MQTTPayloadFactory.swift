import Foundation

enum MQTTPayloadFactory {
    static func envStateFull() -> String {
        """
        {
          "temperature": 26.5,
          "humidity": 61.2,
          "illuminance": 320.0,
          "pm25": 18.0,
          "co2": 650.0,
          "hcho": 0.02,
          "tvoc": 0.15,
          "pressure": 100845.0,
          "smoke_gas": 0.0,
          "type": "sht30",
          "created_at": "2026-04-20T10:30:00+08:00"
        }
        """
    }

    static func envStateTempHumiOnly() -> String {
        """
        {
          "temperature": 26.5,
          "humidity": 61.2,
          "type": "sht30",
          "created_at": "2026-04-20T10:30:00+08:00"
        }
        """
    }

    static func envStateInvalidJSON() -> String {
        """
        {"temperature":26.5,"humidity":
        """
    }

    static func metricsMinimalValid() -> String {
        """
        {
          "unique_id": "ACA704D777EC",
          "created_at": "2026-04-20T10:30:00+08:00"
        }
        """
    }

    static func metricsMissingUniqueId() -> String {
        """
        {
          "created_at": "2026-04-20T10:30:00+08:00"
        }
        """
    }
}
