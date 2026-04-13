#!/bin/bash

# 加载环境变量
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
    echo "✅ 环境变量已加载"
else
    echo "⚠️  未找到 .env 文件，使用默认配置"
fi

# 运行应用
swift run

