#!/bin/bash

# 加载环境变量 .env 文件的存放目录为: ./Sources/App/.env directory
if [ -f ./Sources/App/.env ]; then
    export $(cat './Sources/App/.env' | grep -v '^#' | xargs)
    echo "✅ 环境变量已加载"
else
    echo "⚠️  未找到 .env 文件，使用默认配置"
fi

# 默认：启动应用；`./run.sh --test` 时运行测试
if [ "${1:-}" = "--test" ]; then
    echo "▶ 运行 swift test"
    swift test
else
    echo "▶ 运行 swift run"
    swift run
fi
