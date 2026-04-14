
enum SensorCategory {
    case environment    // 环境：温度、湿度、气压、空气质量
    case motion        // 运动：加速度、陀螺仪
    case gas           // 气体：CO2、TVOC、CH4
    case light         // 光照：亮度、紫外线
    case sound         // 声音：分贝、频率
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
sensor/env/dht22/+/data
sensor/env/sht30/+/data
sensor/env/sht35/+/data

sensor/env/+/+/data
