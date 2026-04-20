

## 当前MQTT主题设计

### MQTT主题设计


```
home/livingroom/env/1/state   // 设备状态（在线/离线/故障等）
home/livingroom/env/1/status(availability)  // 设备状态（在线/离线/故障等）
home/livingroom/env/1/metrics // 设备指标（可选，视设备功能而定）
home/livingroom/env/1/command // 设备控制（可选，视设备功能而定）
home/livingroom/env/1/config  // 设备配置（可选，视设备功能而定）
home/livingroom/env/1/event   // 设备事件（可选，视设备功能而定）,如果设备有报警功能，可以在这里发布报警事件

home/livingroom/light/1/state
home/livingroom/sound/2/state


home/livingroom/edge_device/1/status
home/livingroom/device/1/status
home/livingroom/env/1/status
...



device/system/+/device_info
home/livingroom/env/1/status


// 广播主题（系统级）

home/broadcast/reboot
home/broadcast/update


设备发现（如果对接 Home Assistant）
homeassistant/sensor/env/1/config


```

示例：

温湿度传感器：

```
RAW MQTT: topic=home/livingroom/env/1/state payload={"temp":27.1,"humi":65.4,"type":"sth30","created_at":"2026-04-18T13:42:52+08:00"}
RAW MQTT: topic=home/livingroom/env/2/state payload={"temp":27.1,"humi":65.4,"type":"dht22","created_at":"2026-04-18T13:42:52+08:00"}
RAW MQTT: home/livingroom/env/1/metrics payload={"unique_id":"ACA704D777EC","platform":"esp32c3","os_version":"v5.5.1-931-g9bb7aa84fe","cpu_frequency_mhz":160,"cpu_temperature":"","total_storage_bytes":4194304,"used_storage_bytes":0,"free_storage_bytes":1318001,"storage_usage_percent":68.57641,"total_memory_bytes":300472,"used_memory_bytes":104508,"free_memory_bytes":195964,"memory_usage_percent":34.78128,"uptime_seconds":67206,"reset_reason":0,"ip":"192.168.1.123","subnet":"255.255.255.0","gateway":"192.168.1.1","dns":"192.168.1.1","rssi":"-56","mac":"AC:A7:04:D7:77:EC","created_at":"2026-04-18T13:47:52+08:00"}
```

| 层级       | 示例               | 说明             |
| -------- | ---------------- | -------------- |
| root     | home             | 系统根（可换成公司/项目名） |
| location | livingroom       | 房间             |
| device   | env              | 设备名（逻辑设备）      |
| index    | 1                | 设备编号      |
| endpoint | sensor           | 功能模块（可选但强烈建议）  |
| type     | state/status/... | 数据类型           |

### 订阅策略示例

`home/livingroom/+/+/state` : 监听整个房间
`home/+/+/+/status` : 监听所有设备状态
`home/#` : 监听全系统（不建议，除非做监控工具）



enum SensorCategory {
    case environment    // 环境：温度、湿度、气压、空气质量
    case motion        // 运动：加速度、陀螺仪
    case gas           // 气体：CO2、TVOC、CH4
    case light         // 光照：亮度、紫外线
    case sound         // 声音：分贝、频率
    case camera
    case switch
}

// 建议不同类别使用不同前缀
topic/environment/dht22/001/temperature
topic/motion/mpu6050/001/acceleration
topic/gas/mq135/001/co2


data/sensor/{type}/{id}/{measurement}

示例：
data/sensor/dht22/001/temperature
data/sensor/dht22/001/humidity
data/sensor/sht30/002/temperature

传感器数据主题结构建议：
sensor/env/dht20/+/data

sensor/env/livingroom/dht30



sensor/env/dht20/+/data
sensor/env/dht22/+/data
sensor/env/sht30/+/data
sensor/env/sht35/+/data

sensor/env/dht22/001/temperature
sensor/motion/mpu6050/001/acceleration
sensor/gas/mq135/001/co2

sensor/env/+/+/data


为什么通过fluent中的migrations runMigrations()创建的表，在数据库手动删除后，再重新运行runMigrations()，并不会重新创建新的表？将_fluent_migrations表删除后，还有没有删除的表又会报 error DatabaseManager: [App] Migrations failed: MySQL error: Server error: Table 'sensor_data' already exists

## 1. 删掉业务表后再跑 `runMigrations()`，为什么不建表？

Fluent 判断「要不要执行某个迁移」**只看** `_fluent_migrations` 里有没有这条迁移的 **`name`**，**不会**去扫库里是否还存在 `sensor_data` 等表。

流程等价于：

- 表里已有 `name = CreateSensorData`（举例）→ 认为这条迁移**已经执行过** → **不会再跑** `prepare` → 不会执行 `CREATE TABLE`。
- 你手动 `DROP TABLE sensor_data` 只删了业务表，**没有**删掉 `_fluent_migrations` 里对应行 → 状态仍是「已迁移」→ 所以重新 `runMigrations()` **不会**重建表。

这是设计如此：**迁移状态以 `_fluent_migrations` 为准**，不以「表在不在」为准。

---

## 2. 删掉 `_fluent_migrations` 后为什么报 `sensor_data` already exists？

你只清掉了**迁移记录表**，但 **`sensor_data`（以及可能还有 `sensor_dht22` 等）还在库里**。

删掉 `_fluent_migrations` 后，Fluent 会认为**所有迁移都没跑过**，于是再次执行 `CreateSensorData` 里的 `schema(...).create()`，相当于再执行一次 `CREATE TABLE sensor_data ...`，而表已经存在 → MySQL 就报 **Table already exists**。

也就是说：**要么**表和迁移记录一起对齐（都要么保留、要么都清），**不能**只删一边还指望另一边自动猜对。

---

## 实际该怎么处理

| 目标 | 做法 |
|------|------|
| 只想重建某几张业务表 | 先 `DROP TABLE` 业务表，再删掉 `_fluent_migrations` 里**对应迁移名**的行（或整表清空），再跑 `runMigrations()`。 |
| 想整库从零再来（开发环境） | 删掉相关业务表 **和** 清空/删除 `_fluent_migrations`（或删库重建），再跑迁移。 |
| 只想「补表」又不想动迁移记录 | Fluent 没有内置「发现缺表就再建」；要自己写 SQL / 新迁移，或用手动对齐状态。 |

总结：**`_fluent_migrations` 是「迁移是否跑过」的账本；业务表是「结构是否真的存在」。** 只删表不删账本会不再建表；只删账本不删表会 `CREATE` 撞车报错。
